import java.sql.*;
import java.util.Scanner;

public class ApplicationProfesseur {
    private  Connection connection;
    private final Scanner scanner = new Scanner(System.in);

    private PreparedStatement encoderEtudiant;
    private PreparedStatement encoderEntreprise;
    private PreparedStatement encoderMotCle;
    private PreparedStatement voirStagesnonValidee;
    private PreparedStatement valider_Offre;
    private PreparedStatement voir_offre_stage_valide;
    private PreparedStatement voir_etudiantSansStages;
    private PreparedStatement voir_Offre_Stages_Attribuee;

    public ApplicationProfesseur(){
        // On force le chargement à l'execution
        try {
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            System.out.println("Driver PostgreSQL manquant !");
            System.exit(1);
        }
        System.out.println("Choisissez l'URL de la base de données :");
        System.out.println("1. localhost:5432/postgres");
        System.out.println("2. 172.24.2.6:5432/dbylannmommens");
        System.out.print("Entrez le numéro correspondant à votre choix : ");

        int choix = Integer.parseInt(scanner.nextLine());

        String url;
        String shortUrl;
        switch (choix) {
            case 1:
                url = "jdbc:postgresql://localhost:5432/postgres";
                shortUrl="localhost:5432";
                break;
            case 2:
                url = "jdbc:postgresql://172.24.2.6:5432/dbylannmommens";
                shortUrl= "172.24.2.6:5432/dbylannmommens";
                break;
            default:
                System.out.println("Choix invalide, utilisation de l'URL par défaut : jdbc:postgresql://localhost:5432/postgres");
                url = "jdbc:postgresql://localhost:5432/postgres";
                shortUrl="localhost:5432";
                break;
        }

        // On se connecte
        try {
            System.out.println("*** Veuillez introduire vos informations de connexion a la db ["+shortUrl+"] ***");
            System.out.println();
            System.out.print("Entrez votre nom : ");
            String user = scanner.nextLine();
            System.out.print("Entrez votre mdp : ");
            String mdp = scanner.nextLine();
            connection= DriverManager.getConnection(url,user,mdp);

            //On prépare les prepareStatement
            encoderEtudiant = connection.prepareStatement("SELECT projetBD2.encoderEtudiant(?,?,?,?,?)");
            encoderEntreprise = connection.prepareStatement("SELECT projetBD2.encoderEntreprise(?,?,?,?,?)");
            encoderMotCle = connection.prepareStatement("SELECT projetBD2.encoderMotCle(?)");

            voirStagesnonValidee= connection.prepareStatement("SELECT * FROM projetBD2.voir_Stages_nonValidee");
            voir_offre_stage_valide = connection.prepareStatement("SELECT * FROM ProjetBD2.voir_stages_validee");
            voir_etudiantSansStages = connection.prepareStatement("SELECT * FROM projetBD2.voir_etudiantSansStages");
            voir_Offre_Stages_Attribuee = connection.prepareStatement("SELECT * FROM projetBD2.voir_Offre_Stages_Attribuee");

            valider_Offre = connection.prepareStatement("SELECT projetBD2.valider_Offre(?)");
        } catch (SQLException e) {
            System.out.println("Impossible de joindre le server !");
            System.exit(1);
        }
    }
    public void start() {
        int choix;
       do{
            System.out.println("************** Application Professeur **************");
            System.out.println("Veuillez choisir une option");
            System.out.println("1: encoder un étudiant");
            System.out.println("2: encoder une entreprise");
            System.out.println("3: encoder un mot clé");
            System.out.println("4: voir les offres de stage non validées");
            System.out.println("5. valider une offre de stage (uniquement les non validée)");
            System.out.println("6. voir les offres de stage validées");
            System.out.println("7. voir les étudiants sans stage");
            System.out.println("8. voir les offres de stage attribuées");
            System.out.println("0. Fermer l'application");
            System.out.println();
            System.out.println("Entrez votre choix: ");


            choix = Integer.parseInt(scanner.nextLine());

            switch (choix){
                case 0:
                    close();
                    break;
                case 1:
                    ajouterUnEtudiant();
                    break;
                case 2:
                    ajouterUneEntreprise();
                    break;
                case 3:
                    ajouterMotClef();
                    break;
                case 4:
                    visualiserStageNonValide();
                    break;
                case 5:
                    validerOffre();
                    break;
                case 6:
                    visualiserStageValide();
                    break;
                case 7:
                    visualiserEtudiantsSansStage();
                    break;
                case 8:
                    visualiserOffreStageAttribuee();
                    break;
            }
        } while(choix > 0 && choix < 11);
    }
    private void close(){
        System.out.println("Fermeture de l'application en cours...... ");
        try {
            connection.close();
            System.out.println("L'application est bien fermée");
        }catch (SQLException e){
            System.out.println(e.getMessage());
        }
    }
    private void ajouterUnEtudiant(){
        System.out.println("**** Informations de l'étudiant ****");
        System.out.println("Nom: ");
        String nomEtudiant = scanner.nextLine();
        System.out.println("Prenom: ");
        String prenomEtudiant = scanner.nextLine();
        System.out.println("Email: ");
        String emailEtudiant = scanner.nextLine();
        System.out.println("Semestre (Q1 ou Q2): ");
        String semestreEtudiant = scanner.nextLine();
        System.out.println("mot de passe: ");
        String motDePasseEtudiant = scanner.nextLine();

        try {
            motDePasseEtudiant = BCrypt.hashpw(motDePasseEtudiant, BCrypt.gensalt());

            encoderEtudiant.setString(1, nomEtudiant);
            encoderEtudiant.setString(2, prenomEtudiant);
            encoderEtudiant.setString(3, emailEtudiant);
            encoderEtudiant.setString(4,semestreEtudiant);
            encoderEtudiant.setString(5, motDePasseEtudiant);

            encoderEtudiant.execute();
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }

        System.out.println("L'étudiant a correctement été ajouté ✓");
        System.out.println();
    }
    private void ajouterUneEntreprise(){
        System.out.println("**** Informations de l'entreprise ****");
        System.out.print("Nom: ");
        String nomEntreprise = scanner.nextLine();
        System.out.print("Adresse: ");
        String adresseEntreprise = scanner.nextLine();
        System.out.print("Email: ");
        String emailEntreprise = scanner.nextLine();
        System.out.print("Identifiant: ");
        String identifiantEntreprise = scanner.nextLine();
        System.out.print("Mot de passe: ");
        String motDePasseEntreprise = scanner.nextLine();

        try {
            motDePasseEntreprise = BCrypt.hashpw(motDePasseEntreprise, BCrypt.gensalt());

            encoderEntreprise.setString(1, nomEntreprise);
            encoderEntreprise.setString(2, adresseEntreprise);
            encoderEntreprise.setString(3, emailEntreprise);
            encoderEntreprise.setString(4, identifiantEntreprise);
            encoderEntreprise.setString(5, motDePasseEntreprise);

            boolean success = encoderEntreprise.execute();
            if (success) {
                System.out.println("L'entreprise a correctement été ajoutée ✓");
                System.out.println();
            } else {
                System.out.println("Erreur lors de l'ajout de l'entreprise");
                System.out.println();
            }

        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
    }
    private void ajouterMotClef(){
        System.out.println("Entrez le mot clé: ");
        String motClef = scanner.nextLine();

        try {
            encoderMotCle.setString(1, motClef);

            boolean success = encoderMotCle.execute();
            if (success) {
                System.out.println("Le mot clé a correctement été ajouté ✓");
            } else {
                System.out.println("Erreur lors de l'ajout du mot clé X");
            }

        } catch (SQLException e) {
            System.out.println("Le mot clé est déja présent dans la table mot_clés");
        }
        System.out.println();
    }
    private void visualiserStageNonValide(){
        System.out.println("**** Voir les stages non validés ****");
        System.out.printf("%-15s%-10s%-40s%-50s%n", "Code Stage", "Semestre", "Nom Entreprise", "Description");

        try (ResultSet rs = voirStagesnonValidee.executeQuery()) {
            while (rs.next()) {
                System.out.printf("%-15s%-10s%-40s%-50s%n",
                        rs.getString("code_stage"),
                        rs.getString("semestre"),
                        rs.getString("nom"),
                        rs.getString("description"));
            }
            System.out.println();
            System.out.println("Les stages non validés ont correctement été affiché ✓");
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        System.out.println();
    }
    private void validerOffre(){
        System.out.print("Entrez le code stage à valider: ");
        String codeStage = scanner.nextLine();

        try{
            valider_Offre.setString(1,codeStage);

            boolean success = valider_Offre.execute();

            if (success) {
                System.out.println("L'offre de stage a correctement été validé ✓");
                System.out.println();
            } else {
                System.out.println("Erreur lors de l'ajout de l'offre de stage X");
                System.out.println();
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
    }
    private void visualiserStageValide(){
        System.out.println("**** Voir les stages validés ****");
        System.out.printf("%-15s%-10s%-40s%-50s%n", "Code Stage", "Semestre", "Nom Entreprise", "Description");

        try (ResultSet rs = voir_offre_stage_valide.executeQuery()) {
            while (rs.next()) {
                System.out.printf("%-15s%-10s%-40s%-50s%n",
                        rs.getString("code_stage"),
                        rs.getString("semestre"),
                        rs.getString("nom"),
                        rs.getString("description"));
            }
            System.out.println();
            System.out.println("Les stages validés ont correctement été affiché ✓");
        } catch (SQLException e) {
            System.out.println("Erreur lors de l'affichage des stages validés : " + e.getMessage());
        }
        System.out.println();
    }
    private void visualiserEtudiantsSansStage(){
        System.out.println("**** Voir les étudiants sans stage ****");

        try (ResultSet rs = voir_etudiantSansStages.executeQuery()) {
            System.out.printf("%-15s%-10s%-40s%-50s%-50s%n",
                    "Nom",
                    "Prenom",
                    "Email",
                    "Semestre",
                    "candidature en attente");

            while (rs.next()) {
                System.out.printf("%-15s%-10s%-40s%-50s%-50s%n",
                        rs.getString("nom"),
                        rs.getString("prenom"),
                        rs.getString("email"),
                        rs.getString("semestre"),
                        rs.getString("nombre_candidatures_en_attente")
                );
            }
            System.out.println();
            System.out.println("Les étudiants sans stages on correctement été affiché ✓");
        } catch (SQLException e) {
            System.out.println("Erreur lors de l'affichage des étudiants sans stage : " + e.getMessage());
        }
        System.out.println();
    }
    private void visualiserOffreStageAttribuee(){
        System.out.println("**** Voir les offres de stage attribué ****");

        try(ResultSet rs = voir_Offre_Stages_Attribuee.executeQuery()){
            ResultSetMetaData rsMeta = rs.getMetaData();

            System.out.printf("%-15s%-40s%-20s%-20s%n",
                    rsMeta.getColumnName(1),
                    rsMeta.getColumnName(2),
                    rsMeta.getColumnName(3),
                    rsMeta.getColumnName(4));

           while (rs.next()){
               System.out.printf("%-15s%-40s%-20s%-20s%n",
                       rs.getString("code_stage"),
                       rs.getString("nom_entreprise"),
                       rs.getString("nom_etudiant"),
                       rs.getString("prenom_etudiant")
               );
           }
            System.out.println();
            System.out.println("Les offres de stage attribuées ont correctement été affichées ✓");
        }catch (SQLException e){
            System.out.println("Erreur lors de l'affichage des offres de stage attribuées : " + e.getMessage());
       }
        System.out.println();
    }
}
