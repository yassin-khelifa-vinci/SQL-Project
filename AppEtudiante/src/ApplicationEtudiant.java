import java.sql.*;
import java.util.Scanner;

public class ApplicationEtudiant {

    private Connection connection;
    private Scanner scanner = new Scanner(System.in);
    private int idEtudiant;
    private PreparedStatement voirOffreStageValidees;
    private PreparedStatement rechercherOffreStage;
    private PreparedStatement poserCandidature;
    private PreparedStatement voirOffreStagesAttentes;
    private PreparedStatement annulerCandidature;
    private PreparedStatement login;
    private String email;
    private String mdp;

    public ApplicationEtudiant() {

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

            voirOffreStageValidees = connection.prepareStatement("SELECT * FROM projetBD2.voir_offre_stage_validee WHERE id_etudiant = ?");
            rechercherOffreStage = connection.prepareStatement("SELECT * FROM projetBD2.voir_offre_stage_validee WHERE id_etudiant = ? AND LOWER(mots_cles) LIKE LOWER(?)");
            poserCandidature = connection.prepareStatement("SELECT projetBD2.poser_candidature(?,?,?)");
            voirOffreStagesAttentes = connection.prepareStatement("SELECT * FROM projetBD2.voir_Offre_Stages_Attentes WHERE id_etudiant= ?");
            annulerCandidature = connection.prepareStatement("SELECT projetBD2.annuler_candidature(?,?)");
            login = connection.prepareStatement("SELECT id_etudiant, mot_de_passe from projetBD2.etudiants WHERE email=?");

        } catch (SQLException e) {
            System.out.println("Impossible de joindre le serveur !");
            System.out.println("Message d'erreur : " + e.getMessage());
            e.printStackTrace();
            System.exit(1);
        }
    }

    public void start() {
        int choix = 0;

        System.out.println("**************Application étudiant**************");
        System.out.println("Choisissez une option");
        System.out.println("Option 1 : Se connecter");
        System.out.println("Option 2: Fermer");


        do {


            try {
                choix = Integer.parseInt(scanner.nextLine());
            } catch (NumberFormatException e) {
                System.out.println("Option invalide");
            }

            if (choix < 1 || choix > 2) {
                System.out.println("Veuillez entrer une des deux options !");
                continue;
            }

            if (choix == 1) {
                logIn();
            }


        } while (choix != 2 && choix != 1);


    }

    public void logIn() {
        boolean credentialsValid = false;

        do {
            System.out.println("Email : ");
            email = scanner.nextLine();

            System.out.println("Mot de passe : ");
            mdp =  scanner.nextLine();

            try {
                login.setString(1, email);
            } catch (SQLException e) {
                System.out.println("L'email ou le mdp est faux");
                return;  
            }

            try (ResultSet resultSet = login.executeQuery()) {
                if (resultSet.next()) {
                    String hashedPassword = resultSet.getString(2);
                    if (BCrypt.checkpw(mdp, hashedPassword)) {
                        idEtudiant = resultSet.getInt(1);
                        credentialsValid = true;
                    } else {
                        System.out.println("Mots de passe ou e-mail invalide");
                    }
                } else {
                    System.out.println("Mots de passe ou e-mail invalide");
                }

            } catch (SQLException e) {
                System.out.println("Mot de passe ou email invalide");
            }

        } while (!credentialsValid);

       
        mainMenu();
    }



    private void mainMenu() {
        int choix = 0;

        do {
            System.out.println("**************Menu principal**************");
            System.out.println("Option 1 : Voir les offres de stages");
            System.out.println("Option 2 : Rechercher une offre de stage");
            System.out.println("Option 3 : Poser une candidature");
            System.out.println("Option 4 : Voir les offres de stages pour lesquelles j'ai une candidature");
            System.out.println("Option 5 : Annuler une candidature");
            System.out.println("Option 6 : Fermer");
            System.out.println("******************************************");
            System.out.println("Entrez le numéro d'une option :");

            try {
                choix = Integer.parseInt(scanner.nextLine());

                switch (choix) {
                    case 1 -> {
                        voirOffreStageValidee();
                    }
                    case 2 -> {
                        rechercherOffreStage();
                    }
                    case 3 -> {
                        poserCandidature();
                    }
                    case 4 -> {
                        voirOffreStagesAttentes();
                    }
                    case 5 -> {
                        annulerCandidature();
                    }
                }

            } catch (NumberFormatException e) {
                System.out.println("Entrez une option valide");
            }

            if (choix < 1 || choix > 6) {
                System.out.println("Entrez une option valide");
            }

        } while (choix < 6 && choix > 0);
        start();
    }



    private void voirOffreStageValidee() {
        System.out.println("Les offres validées :");

        try {
            voirOffreStageValidees.setInt(1, idEtudiant);
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }

        try (ResultSet rs = voirOffreStageValidees.executeQuery()) {
            if(rs.wasNull())
                System.out.println("Vous n'avez aucune offre validée");
            else {
                while (rs.next()) {
                    System.out.println("Code: " + rs.getString(1) + ", Nom: " + rs.getString(2) + ", Adresse: " + rs.getString(3) + ", Description: " + rs.getString(4) + ", Mots clés: " + rs.getString(5));
                }
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
    }

    private void rechercherOffreStage() {
        System.out.println("Les offres disponibles :");
        System.out.println("Mot clé du stage: ?");
        String motCle = scanner.nextLine();

        try {
            rechercherOffreStage.setInt(1, idEtudiant);
            rechercherOffreStage.setString(2, "%" + motCle + "%");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }

        try (ResultSet rs = rechercherOffreStage.executeQuery()) {
            if (!rs.next()) {
                System.out.println("Il n'y a aucune offre de stage disponible");
            } else {
                do {
                    System.out.println("Code: " + rs.getString(1) + ", Nom: " + rs.getString(2) + ", Adresse: " + rs.getString(3) + ", Description: " + rs.getString(4) + ", Mot clé: " + rs.getString(5));
                } while (rs.next());
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
    }


    private void poserCandidature() {
        System.out.println("Quel est le code de l'offre pour laquelle vous souhaitez poser une candidature?");
        String code = scanner.nextLine();
        System.out.println("Quelles sont vos motivations pour cette offre de stage?");
        String motivations = scanner.nextLine();

        try {
            poserCandidature.setInt(1, idEtudiant);
            poserCandidature.setString(2, code);
            poserCandidature.setString(3, motivations);
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }


        try (ResultSet resultSet = poserCandidature.executeQuery()) {
            if (resultSet.next()) {
                System.out.println("La candidature a bien été posée!");
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
    }




    private void voirOffreStagesAttentes() {
        System.out.println("Mes candidatures en attente :");

        try {
            voirOffreStagesAttentes.setInt(1, idEtudiant);
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }

        try (ResultSet rs = voirOffreStagesAttentes.executeQuery()) {
            if (rs.wasNull()) {
                System.out.println("Vous n'avez aucune candidature en attente!");
            } else {
                while (rs.next()) {
                    System.out.println("Code du stage: " + rs.getString(2) + ", Nom: " + rs.getString(3) + ", Etat: " + rs.getString(4));
                }
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
    }


    private void annulerCandidature() {
        System.out.println("Quel est le code de l'offre que vous souhaitez annuler?");
        String code = scanner.nextLine();

        try {
            annulerCandidature.setString(2, code);
            annulerCandidature.setInt(1, idEtudiant);
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }


        try (ResultSet resultSet = annulerCandidature.executeQuery()) {
            if (resultSet.next()) {
                System.out.println("La candidature a bien été annulée!");
            }
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
        
    }

}
