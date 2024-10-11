DROP SCHEMA IF EXISTS projetBD2 CASCADE;
CREATE SCHEMA projetBD2;

CREATE TABLE projetBD2.etudiants(
    id_etudiant SERIAL PRIMARY KEY,
    nombre_candidature INTEGER NOT NULL CHECK (nombre_candidature >=0) DEFAULT 0,
    nom VARCHAR(100) NOT NULL CHECK (nom <> ''),
    prenom VARCHAR(100) NOT NULL CHECK (prenom <> ''),
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email SIMILAR TO '%@student.vinci.be'),
    semestre CHAR(2) NOT NULL CHECK (semestre ~ '^(Q1|Q2)$'),
    mot_de_passe VARCHAR(100) NOT NULL
);
CREATE TABLE projetBD2.entreprises(
    identifiant_entreprise CHAR(3) PRIMARY KEY CHECK (upper(identifiant_entreprise) SIMILAR TO identifiant_entreprise),
    nom VARCHAR(100) NOT NULL CHECK (nom <> ''),
    adresse VARCHAR(100) NOT NULL CHECK (nom <> ''),
    email VARCHAR(100) NOT NULL UNIQUE CHECK (email SIMILAR TO '%@%.%'),
    mot_de_passe VARCHAR(100) NOT NULL
);

CREATE TABLE projetBD2.etats_stages(
    id_etat SERIAL PRIMARY KEY,
    intitule VARCHAR(100) NOT NULL UNIQUE
);

CREATE TABLE projetBD2.mots_cles(
    id_mot_cle SERIAL PRIMARY KEY,
    intitule VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE projetBD2.etats_candidatures(
    id_etat_candidature SERIAL PRIMARY KEY,
    intitule VARCHAR(100) NOT NULL UNIQUE
);
CREATE TABLE projetBD2.offres_de_stages(
    id_offre_stage SERIAL PRIMARY KEY ,
    code_stage VARCHAR(20) NOT NULL UNIQUE,
    etat INTEGER REFERENCES projetBD2.etats_stages(id_etat) NOT NULL DEFAULT 1,
    semestre CHAR(2) NOT NULL CHECK (semestre ~ '^(Q1|Q2)$'),
    description TEXT NOT NULL CHECK ( description<>''),
    entreprise CHAR(3) REFERENCES projetBD2.entreprises(identifiant_entreprise) NOT NULL,
    nombre_candidatures  integer NOT NULL DEFAULT 0,
    etudiant integer REFERENCES projetBD2.etudiants(id_etudiant) NULL
);
CREATE TABLE projetBD2.mot_cles_offres(
    offre INTEGER REFERENCES projetBD2.offres_de_stages(id_offre_stage) NOT NULL,
    mot_cle INTEGER REFERENCES projetBD2.mots_cles(id_mot_cle) NOT NULL
);

CREATE TABLE  projetBD2.candidatures(
    etudiant integer REFERENCES  projetBD2.etudiants(id_etudiant) NOT NULL ,
    offre INTEGER REFERENCES projetBD2.offres_de_stages(id_offre_stage) NOT NULL,
    etat INTEGER REFERENCES projetBD2.etats_candidatures(id_etat_candidature) NOT NULL DEFAULT 1,
    motivations TEXT NOT NULL,

    PRIMARY KEY (etudiant, offre)
);

/*
 * ========================================================================
 * Application Générale
 * ========================================================================
 */
-- TRIGGER : actualise le nombre de candidatures de l'etudiants
CREATE OR REPLACE FUNCTION projetBD2.update_student_candidature_count() RETURNS TRIGGER AS $$
    BEGIN
      -- Augmente le nombre de candidatures de l'étudiant associé à la candidature
      UPDATE projetBD2.etudiants
      SET nombre_candidature = nombre_candidature + 1
      WHERE id_etudiant = NEW.etudiant;

      RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_student_candidature_trigger AFTER INSERT ON projetBD2.candidatures
    FOR EACH ROW EXECUTE PROCEDURE projetBD2.update_student_candidature_count();

-- TRIGGER : actualise le nombre de candidatures de l'offre
CREATE OR REPLACE FUNCTION projetBD2.update_offer_candidature_count() RETURNS TRIGGER AS $$
BEGIN
  -- Augmente le nombre de candidatures de l'offre associée à la candidature
  UPDATE projetBD2.offres_de_stages
  SET nombre_candidatures = nombre_candidatures + 1
  WHERE id_offre_stage = NEW.offre;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER update_offer_candidature_trigger BEFORE INSERT
    ON projetBD2.candidatures
    FOR EACH ROW
EXECUTE PROCEDURE projetBD2.update_offer_candidature_count();
/*
 * ========================================================================
 * Application Professeur
 * ========================================================================
 */
 --1.
CREATE OR REPLACE FUNCTION projetBD2.encoderEtudiant(_nom VARCHAR(100),_prenom VARCHAR(100), _email VARCHAR(100), _semestre CHAR(2),_mdp VARCHAR(100)) RETURNS VOID AS $$
    BEGIN
        INSERT INTO projetBD2.etudiants(nom, prenom, email, semestre, mot_de_passe)
        VALUES (_nom,_prenom,_email,_semestre,_mdp);
    END;
$$ LANGUAGE plpgsql;

--2.
CREATE OR REPLACE FUNCTION projetBD2.encoderEntreprise(_nom VARCHAR(100),_adresse VARCHAR(100),_email VARCHAR(100),_identifiant CHAR(3),_mdp VARCHAR(100)) RETURNS VOID AS $$
   BEGIN
        INSERT INTO projetBD2.entreprises(nom, adresse, email,identifiant_entreprise, mot_de_passe)
        VALUES (_nom,_adresse,_email,_identifiant,_mdp);
    END;
$$ LANGUAGE plpgsql;

--3.
CREATE OR REPLACE FUNCTION projetBD2.encoderMotCle(_mot_cle VARCHAR(100)) RETURNS VOID AS $$
    BEGIN
        INSERT INTO projetBD2.mots_cles(intitule)
        VALUES (_mot_cle);
    END;
$$ LANGUAGE plpgsql;

--4.
CREATE OR REPLACE VIEW projetBD2.voir_Stages_nonValidee AS
    SELECT OS.code_stage, OS.semestre, E.nom, OS.description
    FROM projetBD2.offres_de_stages OS, projetBD2.etats_stages ES, projetBD2.entreprises E
    WHERE ES.id_etat = OS.etat
        AND E.identifiant_entreprise = OS.entreprise
        AND ES.intitule = 'non validée';

--5.
CREATE OR REPLACE FUNCTION projetBD2.valider_Offre(_code_stage VARCHAR(20)) RETURNS VOID AS $$
    DECLARE
        _etat_valide integer;
    BEGIN
        -- On vérifie que le _code_stage fait partie de la colonne code_stage dans offres_de_stages
        IF NOT EXISTS (SELECT 1 FROM projetBD2.offres_de_stages WHERE code_stage = _code_stage) THEN
            RAISE EXCEPTION 'L''offre de stage avec le code % n''existe pas', _code_stage;
        END IF;

        -- On récupère l'id de l'état validée
        SELECT id_etat FROM projetBD2.etats_stages WHERE intitule='validée' INTO _etat_valide;

        --On update la table
        UPDATE projetBD2.offres_de_stages SET etat=_etat_valide WHERE code_stage=_code_stage;
        RETURN;
    END
$$ LANGUAGE plpgsql;

CREATE FUNCTION projetBD2.trigger_validation_Offre() RETURNS TRIGGER AS $$
    DECLARE
        _id_etat_nonValide integer;
        _etat_stage integer;
    BEGIN
        --On récupère l'id de l'état 'non validé'
        SELECT id_etat FROM projetBD2.etats_stages where intitule='non validée' into _id_etat_nonValide;
        --On récupère l'id de l'état validé

        --On récupere l'état du stage correspondand dans la table offre de stage
        SELECT etat FROM projetBD2.offres_de_stages WHERE id_offre_stage = NEW.id_offre_stage INTO _etat_stage ;

        IF ( OLD.etat != _id_etat_nonValide ) THEN
            RAISE EXCEPTION 'L''offre a déjà été validée';
        END IF;
        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

DROP TRIGGER trigger_valider ON projetBD2.offres_de_stages;
CREATE TRIGGER trigger_valider BEFORE UPDATE ON projetBD2.offres_de_stages FOR EACH ROW WHEN ( OLD.etat IS DISTINCT FROM NEW.etat AND NEW.etat = 2) EXECUTE PROCEDURE projetBD2.trigger_validation_Offre();
--6
CREATE OR REPLACE VIEW projetBD2.voir_Stages_Validee AS
    SELECT OS.code_stage, OS.semestre, E.nom, OS.description
    FROM projetBD2.offres_de_stages OS, projetBD2.etats_stages ES, projetBD2.entreprises E
    WHERE ES.id_etat = OS.etat
        AND E.identifiant_entreprise = OS.entreprise
        AND ES.intitule = 'validée';

--7.
CREATE OR REPLACE VIEW projetBD2.voir_etudiantSansStages AS
    SELECT e.nom,e.prenom,e.email,e.semestre,COUNT(c.etat) AS nombre_candidatures_en_attente
    FROM projetBD2.etudiants e
    LEFT JOIN projetBD2.candidatures c ON e.id_etudiant = c.etudiant
    LEFT JOIN projetBD2.etats_candidatures ec ON c.etat = ec.id_etat_candidature
WHERE
    c.etat IS NULL OR ec.intitule <> 'acceptée'
GROUP BY
    e.id_etudiant, e.nom, e.prenom, e.email, e.semestre;

--8.
CREATE OR REPLACE VIEW projetBD2.voir_Offre_Stages_Attribuee AS
    SELECT os.code_stage, e.nom AS nom_entreprise, et.nom AS nom_etudiant, et.prenom AS prenom_etudiant
    FROM projetBD2.offres_de_stages os
    JOIN projetBD2.entreprises e ON os.entreprise = e.identifiant_entreprise
    LEFT JOIN projetBD2.etudiants et ON os.etudiant = et.id_etudiant
    JOIN projetBD2.etats_stages es ON os.etat = es.id_etat
    WHERE es.intitule = 'attribuée';

/*
 * ========================================================================
 * Application Etudiante
 * ========================================================================
 */
--Etudiant.1
CREATE OR REPLACE VIEW projetBD2.voir_offre_stage_validee AS
    SELECT o.code_stage,e.nom,e.adresse,o.description,COALESCE(STRING_AGG(mc.intitule, ', '), 'pas de mots clés') AS mots_cles,et.id_etudiant
    FROM projetBD2.entreprises e, projetBD2.etudiants et,projetBD2.offres_de_stages o
        LEFT OUTER JOIN projetBD2.mot_cles_offres mco
        ON o.id_offre_stage = mco.offre
        LEFT OUTER JOIN      projetBD2.mots_cles mc
        ON mco.mot_cle = mc.id_mot_cle
        WHERE e.identifiant_entreprise = o.entreprise
            AND o.etat = 2 AND et.semestre = o.semestre
    GROUP BY et.id_etudiant,o.code_stage,e.nom,e.adresse ,o.description, o.semestre;

--Etudiant.2
--TODO

--Etudiant.3
-- Poser sa candidature. Pour cela, il doit donner le code de l’offre de stage et donner ses
-- motivations sous format textuel. Il ne peut poser de candidature s’il a déjà une
-- candidature acceptée, s’il a déjà posé sa candidature pour cette offre, si l’offre n’est
-- pas dans l’état validée ou si l’offre ne correspond pas au bon semestre.
CREATE OR REPLACE FUNCTION projetBD2.poser_candidature(_id_etudiant INTEGER,_code_offre VARCHAR(10),_motivations TEXT) RETURNS VOID AS $$
    DECLARE
        _id_offre INTEGER;
    BEGIN
        SELECT id_offre_stage FROM projetBD2.offres_de_stages WHERE code_stage = _code_offre INTO _id_offre;

        INSERT INTO projetBD2.candidatures (etudiant, offre, etat, motivations)
        VALUES (_id_etudiant, _id_offre, 1, _motivations);

        UPDATE projetBD2.offres_de_stages
        SET nombre_candidatures = nombre_candidatures
        WHERE id_offre_stage = _id_offre;

    END
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_candidature_acceptee() RETURNS TRIGGER AS $$
    BEGIN
        IF EXISTS ( SELECT 1 FROM projetBD2.candidatures c  WHERE c.etudiant = NEW.etudiant AND c.etat = 2) THEN
            RAISE EXCEPTION 'Vous avez déjà une candidature acceptée!';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_candidature_acceptee BEFORE INSERT ON projetBD2.candidatures FOR EACH ROW
EXECUTE PROCEDURE projetBD2.trigger_verif_candidature_acceptee();

CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_candidature_existante() RETURNS TRIGGER AS $$
    BEGIN
        IF EXISTS (SELECT 1 FROM projetBD2.candidatures c WHERE c.etudiant = NEW.etudiant AND c.offre = NEW.offre ) THEN
            RAISE EXCEPTION 'Vous avez déjà posé votre candidature pour cette offre de stage!';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_candidature_existante BEFORE INSERT ON projetBD2.candidatures FOR EACH ROW
EXECUTE PROCEDURE projetBD2.trigger_verif_candidature_existante();

CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_offre_validee() RETURNS TRIGGER AS $$
    BEGIN
        IF NOT EXISTS (
            SELECT 1
            FROM projetBD2.offres_de_stages o
            WHERE o.id_offre_stage = NEW.offre AND o.etat = 2
        ) THEN
            RAISE EXCEPTION 'Cette offre de stage n''est pas validée!';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_offre_validee BEFORE INSERT ON projetBD2.candidatures FOR EACH ROW
EXECUTE PROCEDURE projetBD2.trigger_verif_offre_validee();

CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_semestre() RETURNS TRIGGER AS $$
    BEGIN
        IF EXISTS (
            SELECT 1
            FROM projetBD2.offres_de_stages o
            JOIN projetBD2.etudiants e ON o.id_offre_stage = NEW.offre AND e.id_etudiant = NEW.etudiant
            WHERE o.semestre <> e.semestre
        ) THEN
            RAISE EXCEPTION 'Cette offre de stage ne correspond pas à votre semestre!';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER before_insert_semestre BEFORE INSERT ON projetBD2.candidatures
FOR EACH ROW EXECUTE PROCEDURE projetBD2.trigger_verif_semestre();

--Etudiant.4
CREATE OR REPLACE VIEW projetBD2.voir_Offre_Stages_Attentes AS
    SELECT et.id_etudiant, o.code_stage, e.nom, ec.intitule
    FROM projetBD2.offres_de_stages o,
         projetBD2.entreprises e,
         projetBD2.candidatures c,
         projetBD2.etats_candidatures ec,
         projetBD2.etudiants et
    WHERE c.offre = o.id_offre_stage
      AND c.etat = ec.id_etat_candidature
      AND c.etudiant = et.id_etudiant
      AND o.entreprise = e.identifiant_entreprise
      AND ec.id_etat_candidature=1;


--Etudiant.5
-- Annuler une candidature en précisant le code de l’offre de stage. Les candidatures ne
--peuvent être annulées que si elles sont « en attente ».
-- Annuler une candidature en précisant le code de l’offre de stage.
-- Les candidatures ne peuvent être annulées que si elles sont « en attente ».
CREATE OR REPLACE FUNCTION projetBD2.annuler_candidature(_id_etudiant INTEGER, _code_offre VARCHAR(10)) RETURNS VOID AS $$
    BEGIN
        UPDATE projetBD2.candidatures
        SET etat = 4
        WHERE offre = (SELECT id_offre_stage FROM projetBD2.offres_de_stages WHERE code_stage = _code_offre)
          AND etudiant = _id_etudiant;

        UPDATE projetBD2.offres_de_stages
        SET nombre_candidatures = nombre_candidatures - 1
        WHERE id_offre_stage = (SELECT id_offre_stage FROM projetBD2.offres_de_stages WHERE code_stage = _code_offre);
    END
$$ LANGUAGE plpgsql;


-- Trigger pour vérifier si la candidature est en attente avant de l'annuler
CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_candidature_en_attente() RETURNS TRIGGER AS $$
    BEGIN
        IF (
            SELECT c.etat
            FROM projetBD2.candidatures c
            WHERE c.offre = NEW.offre AND c.etudiant = NEW.etudiant) != 1
            THEN
            RAISE EXCEPTION 'Cette candidature n''est pas en attente!';
        END IF;

        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

DROP TRIGGER before_update_candidature_en_attente ON projetBD2.candidatures;
CREATE TRIGGER before_update_candidature_en_attente BEFORE UPDATE ON projetBD2.candidatures
FOR EACH ROW WHEN ( NEW.etat = 4  ) EXECUTE PROCEDURE projetBD2.trigger_verif_candidature_en_attente();

/*
 * ========================================================================
 * Application Entreprise
 * ======================================================================
 */

--insère une offre de stage
CREATE OR REPLACE FUNCTION projetBD2.addOffreStage(identifiant CHAR(3), description1 TEXT, semestre1 CHAR(2))RETURNS VOID AS $$
    DECLARE
        nbStages integer;
    BEGIN
        nbStages = (SELECT count(*) FROM projetBD2.offres_de_stages o WHERE o.entreprise = identifiant) + 1;
        INSERT INTO projetBD2.offres_de_stages (code_stage, semestre, description, entreprise)
        VALUES (identifiant || nbStages, semestre1, description1, identifiant);
    END
$$ LANGUAGE plpgsql;

-- Création du trigger empêchant d'ajouter une offre pour une entreprise qui a déjà accepté une offre
CREATE OR REPLACE FUNCTION checkOffreStage() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        -- Vérifie si une offre de stage a déjà été attribuée pour la même entreprise et le même semestre
        IF EXISTS (SELECT 1 FROM projetBD2.offres_de_stages o WHERE o.entreprise = NEW.entreprise AND o.semestre = NEW.semestre AND o.etat = 3)THEN
            RAISE EXCEPTION 'Il y a déjà un stage attribué pour cette entreprise et ce semestre';
        END IF;
        RETURN NEW;
    END;
$$ LANGUAGE plpgsql;

-- Création du trigger BEFORE INSERT offre de stage
CREATE TRIGGER checkOffreStageTrigger BEFORE INSERT ON projetBD2.offres_de_stages
FOR EACH ROW EXECUTE PROCEDURE checkOffreStage();

-- ajouter un mot clé à une offre de stage
CREATE OR REPLACE FUNCTION projetBD2.addMotcleOffre(id_entreprise CHAR(3), _mot_cle VARCHAR(25), _code VARCHAR(10))RETURNS VOID AS $$
    DECLARE
        _id_offre INTEGER;
        _id_mot_cle INTEGER;
    BEGIN
        IF NOT EXISTS(SELECT * FROM projetBD2.offres_de_stages WHERE code_stage = _code AND entreprise = id_entreprise)THEN
            RAISE EXCEPTION 'Ceci n''est pas une de vos offres de stages';
        END IF;

        SELECT id_offre_stage FROM projetBD2.offres_de_stages WHERE code_stage = _code INTO _id_offre;
        SELECT id_mot_cle FROM projetBD2.mots_cles WHERE LOWER(intitule) = LOWER(_mot_cle) INTO _id_mot_cle;

        INSERT INTO projetBD2.mot_cles_offres (offre, mot_cle)
        VALUES (_id_offre, _id_mot_cle);
    END
$$ LANGUAGE plpgsql;

-- Création du trigger empêchant d'ajouter un mot clé à une offre si elle en a 3 ou
CREATE OR REPLACE FUNCTION projetBD2.trigger_add_mot_cle_offre() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        IF (SELECT o.etat FROM projetBD2.offres_de_stages o WHERE o.id_offre_stage = NEW.offre) IN (3, 4) THEN
            RAISE EXCEPTION 'L''offre de stage n''est plus disponible' ;
        END IF;

        IF (SELECT COUNT(m.*) FROM projetBD2.mot_cles_offres m WHERE m.offre = NEW.offre) = 3 THEN
            RAISE EXCEPTION 'Il y a déjà 3 mots clés pour cette offre de stage';
        END IF;

        IF (SELECT COUNT(m.*) FROM projetBD2.mot_cles_offres m WHERE m.offre = NEW.offre AND m.mot_cle = NEW.mot_cle) = 1 THEN
            RAISE EXCEPTION 'Ce mot clé est déjà associé à cette offre de stage';
        END IF;

        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger BEFORE INSERT offre de stage
CREATE TRIGGER checkMotCleOffreTrigger BEFORE INSERT ON projetBD2.mot_cles_offres
FOR EACH ROW EXECUTE PROCEDURE projetBD2.trigger_add_mot_cle_offre();

--afficher les offres de stages
CREATE OR REPLACE VIEW projetBD2.voir_Offre_Stages AS
    SELECT o.code_stage, o.description, o.semestre, es.intitule, o.nombre_candidatures, COALESCE(e.nom, 'pas attribué') AS nom, en.identifiant_entreprise
    FROM projetBD2.entreprises en, projetBD2.etats_stages es, projetBD2.offres_de_stages o
    LEFT OUTER JOIN projetBD2.etudiants e ON o.etudiant = e.id_etudiant
    WHERE es.id_etat = o.etat AND o.entreprise = en.identifiant_entreprise;

--afficher les mots clés existants
CREATE OR REPLACE VIEW projetBD2.voir_Mots_Cles AS
    SELECT mc.intitule
    FROM projetBD2.mots_cles mc;

--afficher les candidatures pour une offre
CREATE OR REPLACE VIEW projetBD2.voir_Candidatures_Stages AS
    SELECT ec.intitule, e.nom, e.prenom, e.email, c.motivations, o.code_stage
    FROM projetBD2.etats_candidatures ec, projetBD2.offres_de_stages o, projetBD2.candidatures c, projetBD2.etudiants e
    WHERE ec.id_etat_candidature = c.etat AND c.etudiant = e.id_etudiant AND c.offre = o.id_offre_stage;

-- valide une candidature pour une offre
CREATE OR REPLACE FUNCTION projetBD2.valider_candidature(_id_entreprise CHAR(3), _code_offre VARCHAR(10), _email VARCHAR(100))RETURNS VOID AS $$
    DECLARE
        _id_etudiant INTEGER;
    BEGIN
        IF NOT EXISTS(
            SELECT * FROM projetBD2.offres_de_stages
            WHERE code_stage = _code_offre AND entreprise = _id_entreprise
        )
        THEN
            RAISE EXCEPTION 'Ceci n''est pas une de vos offres de stages';
        END IF;

        SELECT id_etudiant FROM projetBD2.etudiants e WHERE e.email = _email INTO _id_etudiant;
        UPDATE projetBD2.offres_de_stages
        SET etudiant = _id_etudiant
        WHERE code_stage = _code_offre;

    END
$$ LANGUAGE plpgsql;

--SELECT projetBD2.valider_candidature('ULB', 'VIN1', 'maxime.issa@student.vinci.be')

-- Création du trigger empêchant de valider une candidature si l'offre de stage n'est pas validée
-- ou si la candidature n'est pas en attente ou si il n'y a pas de candidature pour cette offre
CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_valider_candidature() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        IF (SELECT o.etat FROM projetBD2.offres_de_stages o WHERE o.id_offre_stage = NEW.id_offre_stage) <> 2 THEN
            RAISE EXCEPTION 'L''offre de stage n''est pas validée' ;
        END IF;

        IF (SELECT COUNT(c.*) FROM projetBD2.candidatures c WHERE c.offre = NEW.id_offre_stage AND c.etudiant = NEW.etudiant) = 0 THEN
            RAISE EXCEPTION 'Il n''y a pas de candidature pour cette offre de stage' ;
        END IF;

        IF (SELECT c.etat FROM projetBD2.candidatures c WHERE c.etudiant = NEW.etudiant AND c.offre = NEW.id_offre_stage) <> 1 THEN
            RAISE EXCEPTION 'La candidature n''est pas en attente' ;
        END IF;

        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger BEFORE UPDATE etudiant offre de stage
CREATE TRIGGER checkValiderCandidatureTrigger BEFORE UPDATE ON projetBD2.offres_de_stages
FOR EACH ROW WHEN ( NEW.etudiant IS NOT NULL ) EXECUTE PROCEDURE projetBD2.trigger_verif_valider_candidature();

-- passer etat offre de stage à attribuée et etat candidature à acceptée
-- et les autres candidatures de l'étudiant à annulée
CREATE OR REPLACE FUNCTION projetBD2.trigger_post_valider_candidature() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        UPDATE projetBD2.offres_de_stages
        SET etat = 3
        WHERE id_offre_stage = NEW.id_offre_stage;
        UPDATE projetBD2.offres_de_stages
        SET etat = 4
        WHERE entreprise = NEW.entreprise AND semestre = NEW.semestre AND id_offre_stage <> NEW.id_offre_stage;
        UPDATE projetBD2.candidatures
        SET etat = 2
        WHERE offre = NEW.id_offre_stage AND etudiant = NEW.etudiant;
        UPDATE projetBD2.candidatures
        SET etat = 4
        WHERE offre != NEW.id_offre_stage AND etudiant = NEW.etudiant AND etat = 1;
        UPDATE projetBD2.candidatures
        SET etat = 3
        WHERE offre = NEW.id_offre_stage AND etudiant <> NEW.etudiant;
        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger BEFORE UPDATE etudiant offre de stage
DROP TRIGGER trigger_post_valider_candidature ON projetBD2.offres_de_stages
CREATE TRIGGER trigger_post_valider_candidature AFTER UPDATE ON projetBD2.offres_de_stages
FOR EACH ROW WHEN ( NEW.etudiant IS DISTINCT FROM OLD.etudiant ) EXECUTE PROCEDURE projetBD2.trigger_post_valider_candidature();

-- passer etat candidature à refusée pour une offre de stage annulée
CREATE OR REPLACE FUNCTION projetBD2.trigger_annuler_candidatures() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        UPDATE projetBD2.candidatures
        SET etat = 3
        WHERE offre = NEW.id_offre_stage;
        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger After UPDATE etat offre de stage a annulée
CREATE TRIGGER trigger_annuler_candidatures AFTER UPDATE ON projetBD2.offres_de_stages
FOR EACH ROW WHEN ( NEW.etat != OLD.etat AND NEW.etat = 4 ) EXECUTE PROCEDURE projetBD2.trigger_annuler_candidatures();

-- annuler une offre de stage
CREATE OR REPLACE FUNCTION projetBD2.annuler_offre(_id_entreprise CHAR(3), _code_offre VARCHAR(10))RETURNS VOID AS $$
    DECLARE
    BEGIN
        IF NOT EXISTS(
            SELECT *
            FROM projetBD2.offres_de_stages
            WHERE code_stage = _code_offre AND entreprise = _id_entreprise
        )
        THEN
            RAISE EXCEPTION 'Ceci n''est pas une de vos offres de stages';
        END IF;
        UPDATE projetBD2.offres_de_stages
        SET etat = 4
        WHERE code_stage = _code_offre;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger empêchant d'annuler une offre de stage si elle est déjà annulée ou attribuée
CREATE OR REPLACE FUNCTION projetBD2.trigger_verif_annuler_offre() RETURNS TRIGGER AS $$
    DECLARE
    BEGIN
        IF OLD.etat = 4 THEN
            RAISE EXCEPTION 'L''offre de stage est déjà annulée' ;
        END IF;

        IF OLD.etat = 3 THEN
            RAISE EXCEPTION 'L''offre de stage est déjà attribuée' ;
        END IF;
        RETURN NEW;
    END
$$ LANGUAGE plpgsql;

-- Création du trigger BEFORE UPDATE etat offre de stage
CREATE TRIGGER checkAnnulerOffreTrigger BEFORE UPDATE ON projetBD2.offres_de_stages
FOR EACH ROW WHEN ( NEW.etat = 4 ) EXECUTE PROCEDURE projetBD2.trigger_verif_annuler_offre();

/*
 * ========================================================================
 * Données d'insertion
 * ======================================================================
 */

--Donnée pour la table étudiants
INSERT INTO projetBD2.etudiants (nom, prenom, email, semestre, mot_de_passe)
VALUES ('De','Jean','j.d@student.vinci.be','Q2','$2a$12$kpH8L5Oq/ZAKi6fK43JAtOjMoZcIeMgP19VVSLux6iqJEnaktfFCi'); --Azerty123
INSERT INTO projetBD2.etudiants (nom, prenom, email, semestre, mot_de_passe)
VALUES ('Du','Marc','m.d@student.vinci.be','Q1','$2a$10$fHWLZNhubD785hJLBka/e..flTyk78GDWhaVl8xsFj8AFmmrkUTRC'); --Hachieparmentier

-- Données pour la table entreprises
INSERT INTO projetBD2.entreprises (identifiant_entreprise, nom, adresse, email, mot_de_passe)
VALUES ('VIN', 'Haute école léonard de vinci', 'Pl. de Alma 3, 1200 Woluwe-Saint-Lambert', 'contact@vinci.be', '$2a$12$ou410GdiZ4nEV29JBuNDSe.jtXL/ex8AcP4HKUxnRC8/VF14sTVB6');
INSERT INTO projetBD2.entreprises (identifiant_entreprise, nom, adresse, email, mot_de_passe)
VALUES ('ULB', 'Université Libre de Bruxelle', 'Campus du solbosch', 'contact@ulb.be', 'PasswordB');

-- Données pour la table etats_candidatures
INSERT INTO projetBD2.etats_candidatures (intitule)
VALUES ('en attente');
INSERT INTO projetBD2.etats_candidatures (intitule)
VALUES ('acceptée');
INSERT INTO projetBD2.etats_candidatures (intitule)
VALUES ('refusée');
INSERT INTO projetBD2.etats_candidatures (intitule)
VALUES ('annulée');

-- Données pour la table etats_stages
INSERT INTO projetBD2.etats_stages (intitule)
VALUES ('non validée');
INSERT INTO projetBD2.etats_stages (intitule)
VALUES ('validée');
INSERT INTO projetBD2.etats_stages (intitule)
VALUES ('attribuée');
INSERT INTO projetBD2.etats_stages (intitule)
VALUES ('annulée');

-- Données pour la table mots_cles
INSERT INTO projetBD2.mots_cles (intitule)
VALUES ('Java');
INSERT INTO projetBD2.mots_cles (intitule)
VALUES ('Python');
INSERT INTO projetBD2.mots_cles (intitule)
VALUES ('Web');

-- Données pour la table offres_de_stages
INSERT INTO projetBD2.offres_de_stages (code_stage, etat, semestre, description, entreprise, etudiant)
VALUES ('VIN1',2, 'Q2', 'Stage SAP', 'VIN', NULL);
INSERT INTO projetBD2.offres_de_stages (code_stage, semestre, description, entreprise, etudiant)
VALUES ('VIN2', 'Q2', 'Stage BI', 'VIN', NULL);
INSERT INTO projetBD2.offres_de_stages (code_stage, semestre, description, entreprise, etudiant)
VALUES ('VIN3', 'Q2', 'Stage Unity', 'VIN', NULL);
INSERT INTO projetBD2.offres_de_stages (code_stage, etat, semestre, description, entreprise, etudiant)
VALUES ('VIN4',2, 'Q2', 'Stage IA', 'VIN', NULL);
INSERT INTO projetBD2.offres_de_stages (code_stage, etat, semestre, description, entreprise, etudiant)
VALUES ('VIN5',2, 'Q1', 'Stage mobile', 'VIN', NULL);
INSERT INTO projetBD2.offres_de_stages (code_stage, etat, semestre, description, entreprise, etudiant)
VALUES ('ULB1',2, 'Q2', 'Stage javascript', 'ULB', NULL);

-- Données pour la table mot_cles_offres
INSERT INTO projetBD2.mot_cles_offres (offre, mot_cle)
VALUES (3,1);
INSERT INTO projetBD2.mot_cles_offres (offre, mot_cle)
VALUES (5,1);

-- Données pour la table candidatures
INSERT INTO projetBD2.candidatures (etudiant, offre, motivations)
VALUES (1,4, 'Motivations pour candidature 1');
INSERT INTO projetBD2.candidatures(etudiant, offre, motivations)
VALUES (2,5,'Motivations pour candidature 2');
/*
 * ========================================================================
 * Droit utilisateur
 * ======================================================================
*/
GRANT CONNECT ON DATABASE dbylannmommens TO yassinkhelifa,maximeissa;
GRANT USAGE ON SCHEMA projetBD2 TO yassinkhelifa,maximeissa;

GRANT SELECT ON ALL TABLES IN SCHEMA projetBD2 TO yassinkhelifa,maximeissa;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA projetBD2 to yassinkhelifa,maximeissa;

--1.
GRANT SELECT ON projetBD2.voir_offre_stage_validee TO maximeissa;
--2.
--3.
GRANT INSERT ON projetBD2.candidatures TO maximeissa;
GRANT UPDATE ON projetBD2.offres_de_stages TO maximeissa;
GRANT UPDATE ON projetBD2.etudiants TO maximeissa;
--4.
GRANT SELECT ON projetBD2.voir_Offre_Stages_Attentes to maximeissa;
--5
GRANT UPDATE ON projetBD2.candidatures TO maximeissa;

--1
GRANT INSERT ON projetBD2.offres_de_stages TO yassinkhelifa;
--2
GRANT SELECT ON projetBD2.voir_Mots_Cles TO yassinkhelifa;
--3
GRANT INSERT ON projetBD2.mot_cles_offres TO yassinkhelifa;
--4
GRANT SELECT ON projetBD2.voir_Offre_Stages TO yassinkhelifa;
--5
GRANT SELECT ON projetBD2.voir_Candidatures_Stages TO yassinkhelifa;
--6
GRANT UPDATE ON projetBD2.offres_de_stages TO yassinkhelifa;
GRANT UPDATE ON projetBD2.candidatures TO yassinkhelifa;
