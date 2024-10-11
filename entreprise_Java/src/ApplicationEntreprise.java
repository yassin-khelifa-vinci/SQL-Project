import java.sql.*;
import java.util.Scanner;

public class ApplicationEntreprise {
    private Connection connection;
    private final Scanner scanner = new Scanner(System.in);

    private PreparedStatement login;
    private PreparedStatement addOffreStage;
    private PreparedStatement addMotClefOffre;
    private PreparedStatement voir_mots_cles;
    private PreparedStatement voir_offres_stages;
    private PreparedStatement voir_candidatures_offre;
    private PreparedStatement valider_candidature;
    private PreparedStatement annuler_offre;
    private String identifiant;


    public ApplicationEntreprise() {
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
            login = connection.prepareStatement("SELECT * from projetBD2.entreprises WHERE identifiant_entreprise = ?");
            addOffreStage = connection.prepareStatement("SELECT projetBD2.addOffreStage(?, ?, ?)");
            addMotClefOffre = connection.prepareStatement("SELECT projetBD2.addMotcleOffre(?, ?, ?)");
            voir_offres_stages = connection.prepareStatement("SELECT * FROM projetBD2.voir_Offre_Stages WHERE identifiant_entreprise = ?");
            voir_mots_cles = connection.prepareStatement("SELECT * FROM projetBD2.voir_Mots_Cles");
            voir_candidatures_offre = connection.prepareStatement("SELECT * FROM projetBD2.voir_Candidatures_Stages WHERE code_stage = ?");
            valider_candidature = connection.prepareStatement("SELECT projetBD2.valider_candidature(?, ?, ?)");
            annuler_offre = connection.prepareStatement("SELECT projetBD2.annuler_offre(?, ?)");

        } catch (SQLException e) {
            System.out.println("Impossible de joindre le server !");
            System.exit(1);
        }
    }

    public void start() {
        int choix = 0;

        System.out.println("**************Application entreprise**************");
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
            if (choix == 2) {
                close();
            }


        } while (choix != 2 && choix != 1);


    }

    public void mainMenu() {
        int choix = 0;
        do {
            System.out.println("************** Application Entreprise **************");
            System.out.println("Veuillez choisir une option");
            System.out.println("1: encoder une offre de stage");
            System.out.println("2: voir les mots clés disponibles");
            System.out.println("3: Ajouter un mot-clé à une de vos offres de stage");
            System.out.println("4: Voir vos offres de stages");
            System.out.println("5: Voir les candidatures pour une de vos offres de stages");
            System.out.println("6: Sélectionner un étudiant pour une de vos offres de stage");
            System.out.println("7: Annuler une offre de stage");
            System.out.println("0: Fermer l'application");
            System.out.println();
            System.out.println("Entrez votre choix: ");


            choix = Integer.parseInt(scanner.nextLine());

            switch (choix) {
                case 1:
                    ajouterUneOffreDeStage();
                    break;
                case 2:
                    voirMotsCles();
                    break;
                case 3:
                    addMotClefOffre();
                    break;
                case 4:
                    voir_offres_stages();
                    break;
                case 5:
                    voir_candidatures_offre();
                    break;
                case 6:
                    valider_candidature();
                    break;
                case 7:
                    annuler_offre();
                    break;
            }
        } while (choix > 0 && choix < 8);
        start();
    }

    public void logIn() {
        boolean credentialsValid = false;
// $2a$10$43CR2IK16dW/NXM1uipdee2a6y1l2.tE8Cqy61LIhaia6ISyGd9P2
        do {
            System.out.println("Identifiant : ");
            identifiant = scanner.nextLine();

            System.out.println("Mot de passe : ");
            String mdp =  scanner.nextLine();

            try {
                login.setString(1, identifiant);
            } catch (SQLException e) {
                System.out.println("L'email ou le mdp est faux");
                return;  // Quitter la méthode en cas d'erreur
            }

            try (ResultSet resultSet = login.executeQuery()) {
                if (resultSet.next()) {
                    String hashedPassword = resultSet.getString(5);
                    if (BCrypt.checkpw(mdp, hashedPassword)) {
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

    private void close(){
        System.out.println("Fermeture de l'application en cours...... ");
        try {
            connection.close();
            System.out.println("L'application est bien fermé");
        }catch (SQLException e){
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
    }
    private void ajouterUneOffreDeStage(){
        System.out.println("**** Informations du stage ****");
        System.out.println("Donnez une brève description :");
        String description = scanner.nextLine();
        System.out.println("Semestre (Q1 ou Q2): ");
        String semestre = scanner.nextLine();

        try {
            addOffreStage.setString(1, identifiant);
            addOffreStage.setString(2, description);
            addOffreStage.setString(3, semestre);

            addOffreStage.execute();
            System.out.println("L'offre de stage a correctement été ajouté ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }

        System.out.println();
    }
    private void voirMotsCles(){
        System.out.println("**** Voir les mots clés disponibles ****");

        try (ResultSet rs = voir_mots_cles.executeQuery()) {
            while (rs.next()) {
                System.out.printf("%-15s%n",
                        rs.getString("intitule")
                );
            }
            System.out.println();
            System.out.println("Les mots cles ont correctement été affiché ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
        System.out.println();
    }

    private void addMotClefOffre(){
        System.out.println("**** Ajouter un mot clé à une de vos offres de stage ****");
        System.out.println("Entrez l'identifiant de l'offre de stage :");
        String idOffre = scanner.nextLine();
        System.out.println("Entrez le mot clé :");
        String motCle = scanner.nextLine();

        try {
            addMotClefOffre.setString(1, identifiant);
            addMotClefOffre.setString(2, motCle);
            addMotClefOffre.setString(3, idOffre);

            addMotClefOffre.execute();
            System.out.println("Le mot clé a correctement été ajouté à l'offre de stage ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }

        System.out.println();
    }

    private void voir_offres_stages(){
        System.out.println("*********************************************************** Voir vos offres de stages *************************************************************************************************************************************************************\n");
        System.out.printf("%-10s%-40s%-15s%-15s%-30s%-40s%n", "Code", "Description", "Semestre", "État", "Nombre de candidatures", "Étudiant sélectionné");
        try {
            voir_offres_stages.setString(1, identifiant);
        } catch (SQLException e) {
            throw new RuntimeException(e);
        }
        try (ResultSet rs = voir_offres_stages.executeQuery()) {
            while (rs.next()) {
                System.out.printf("%-10s%-40s%-15s%-15s%-30s%-40s%n",
                        rs.getString("code_stage"),
                        rs.getString("description"),
                        rs.getString("semestre"),
                        rs.getString("intitule"),
                        rs.getString("nombre_candidatures"),
                        rs.getString("nom")
                );
            }
            System.out.println();
            System.out.println("Les offres de stages ont correctement été affiché ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage());
        }
        System.out.println();
    }

    private void voir_candidatures_offre(){
        System.out.println("*********************************************************** Voir les candidatures pour une de vos offres de stages *************************************************************************************************************************************************************\n");
        System.out.println("Entrez l'identifiant de l'offre de stage :");
        String idOffre = scanner.nextLine();

        try {
            voir_candidatures_offre.setString(1, idOffre);
            ResultSet rs = voir_candidatures_offre.executeQuery();
            if (!idOffre.substring(0, 3).equals(identifiant) || rs.wasNull()){
                System.out.println("Il n'y a pas de candidatures pour cette offre ou vous n'avez pas d'offre ayant ce code");
                return;
            }

            System.out.printf("%-20s%-20s%-20s%-40s%-50s%n", "État", "Nom", "Prénom", "Email", "Motivation");
            while (rs.next()) {
                System.out.printf("%-20s%-20s%-20s%-40s%-50s%n",
                        rs.getString("intitule"),
                        rs.getString("nom"),
                        rs.getString("prenom"),
                        rs.getString("email"),
                        rs.getString("motivations")
                );
            }
            System.out.println();
            System.out.println("Les candidatures pour l'offre de stage ont correctement été affiché ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
        System.out.println();
    }

    private void valider_candidature(){
        System.out.println("****************** Sélectionner un étudiant pour une de vos offres de stage *************************************************************************************************************************************************************\n");
        System.out.println("Entrez l'identifiant de l'offre de stage :");
        String idOffre = scanner.nextLine();
        System.out.println("Entrez l'adresse mail de l'étudiant :");
        String emailEtudiant = scanner.nextLine();

        try {
            valider_candidature.setString(1, identifiant);
            valider_candidature.setString(2, idOffre);
            valider_candidature.setString(3, emailEtudiant);
            valider_candidature.execute();
            System.out.println("L'étudiant a correctement été sélectionné pour l'offre de stage ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
        System.out.println();
    }

    private void annuler_offre(){
        System.out.println("****************** Annuler une offre de stage *************************************************************************************************************************************************************\n");
        System.out.println("Entrez l'identifiant de l'offre de stage :");
        String idOffre = scanner.nextLine();

        try {
            annuler_offre.setString(1, identifiant);
            annuler_offre.setString(2, idOffre);
            annuler_offre.execute();
            System.out.println("L'offre de stage a correctement été annulé ✓");
        } catch (SQLException e) {
            System.out.println(e.getMessage().split("\n")[0].split(": ")[1]);
        }
        System.out.println();
    }

}
