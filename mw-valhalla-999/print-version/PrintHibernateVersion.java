import org.hibernate.Version;

public class PrintHibernateVersion {
    public static void main(String[] args) {
        String version = Version.getVersionString();
        System.out.println("Hibernate version: " + version);
    }
}
