import org.hibernate.Version;

public class PrintHibernateVersion {
    public static void main(String[] args) {
        String version = Version.getVersionString();
        System.out.println("Hibernate version: " + version);
        System.out.println("EntityKey is value class? " + isValueClass(org.hibernate.engine.spi.EntityKey));
    }

    private static final Object IDENTITY_FLAG = findIdentityFlag();
    private static final Method ACCESS_FLAGS = findAccessFlagsMethod();

    private static Object findIdentityFlag() {
        try {
            Class<?> accessFlag =
                Class.forName("java.lang.reflect.AccessFlag");

            @SuppressWarnings({"rawtypes", "unchecked"})
            Object identity = Enum.valueOf(
                (Class<? extends Enum>) accessFlag.asSubclass(Enum.class),
                "IDENTITY");

            return identity;
        } catch (ClassNotFoundException | IllegalArgumentException e) {
            return null;
        }
    }

    private static Method findAccessFlagsMethod() {
        try {
            return Class.class.getMethod("accessFlags");
        } catch (NoSuchMethodException e) {
            return null;
        }
    }

    public static boolean isValueClass(Class<?> clazz) {
        if (IDENTITY_FLAG == null || ACCESS_FLAGS == null) {
            // This VM does not support value classes.
            return false;
        }

        if (clazz.isPrimitive() || clazz.isArray() || clazz.isInterface()) {
            return false;
        }

        try {
            Set<?> flags = (Set<?>) ACCESS_FLAGS.invoke(clazz);
            return !flags.contains(IDENTITY_FLAG);
        } catch (ReflectiveOperationException e) {
            throw new RuntimeException(e);
        }
    }
}
