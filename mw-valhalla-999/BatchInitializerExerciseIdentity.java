import java.lang.reflect.Field;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

import org.hibernate.engine.spi.EntityEntry;
import org.hibernate.engine.spi.EntityKey;
import org.hibernate.engine.spi.PersistenceContext;
import org.hibernate.engine.spi.SessionFactoryImplementor;
import org.hibernate.engine.spi.SharedSessionContractImplementor;
import org.hibernate.metamodel.mapping.AttributeMapping;
import org.hibernate.persister.entity.EntityPersister;
import org.hibernate.property.access.spi.Setter;
import org.hibernate.sql.results.graph.Initializer;
import org.hibernate.sql.results.graph.InitializerData;
import org.hibernate.sql.results.graph.entity.EntityInitializer;
import org.hibernate.sql.results.graph.entity.internal.BatchEntitySelectFetchInitializer;
import org.hibernate.sql.results.graph.entity.internal.BatchEntitySelectFetchInitializer.BatchEntitySelectFetchInitializerData;
import org.hibernate.sql.results.jdbc.spi.RowProcessingState;
import org.hibernate.type.Type;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyBoolean;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Standalone exercise of {@link BatchEntitySelectFetchInitializer}'s
 * {@code registerResolutionListener} and {@code endLoading} methods.
 *
 * Creates one (EntityKey, List&lt;ParentInfo&gt;) entry with 3 elements
 * in the toBatchLoad map via registerResolutionListener, then calls
 * endLoading to iterate over them.
 */
public class BatchInitializerExercise {

    public static void main(String[] args) throws Exception {

        // ── Mock infrastructure ──────────────────────────────────────

        // Session / factory / persistence-context
        SharedSessionContractImplementor session = mock(SharedSessionContractImplementor.class);
        SessionFactoryImplementor factory = mock(SessionFactoryImplementor.class);
        PersistenceContext persistenceContext = mock(PersistenceContext.class);
        when(session.getFactory()).thenReturn(factory);
        when(session.getPersistenceContextInternal()).thenReturn(persistenceContext);

        // RowProcessingState
        RowProcessingState rowProcessingState = mock(RowProcessingState.class);
        when(rowProcessingState.getSession()).thenReturn(session);

        // EntityPersister (needed for EntityKey construction)
        EntityPersister persister = mock(EntityPersister.class);
        when(persister.getRootEntityName()).thenReturn("FakeEntity");
        when(persister.getEntityName()).thenReturn("FakeEntity");
        when(persister.getSubclassId()).thenReturn(0);

        Type identifierType = mock(Type.class);
        when(identifierType.getTypeForEqualsHashCode()).thenReturn(null); // forces id.hashCode() path
        when(persister.getIdentifierType()).thenReturn(identifierType);
        when(persister.getFactory()).thenReturn(factory);

        // Build a single EntityKey that all 3 calls will share
        Object entityId = 42L;
        EntityKey entityKey = new EntityKey(entityId, persister);

        // Owning entity initializer (returned by owningEntityInitializer field)
        @SuppressWarnings("unchecked")
        EntityInitializer<InitializerData> owningInit =
                mock(EntityInitializer.class);

        // owningData — state != INITIALIZED so ParentInfo is always added
        InitializerData owningData = mock(InitializerData.class);
        when(owningData.getState()).thenReturn(Initializer.State.RESOLVED);
        when(owningInit.getData(any(RowProcessingState.class))).thenReturn(owningData);

        // concreteDescriptor for owning init → subclassId = 0
        EntityPersister owningPersister = mock(EntityPersister.class);
        when(owningPersister.getSubclassId()).thenReturn(0);
        when(owningInit.getConcreteDescriptor(owningData)).thenReturn(owningPersister);

        // Three distinct parent instances
        Object parent1 = new Object();
        Object parent2 = new Object();
        Object parent3 = new Object();

        // An AttributeMapping at index 0 of parentAttributes[]
        AttributeMapping parentAttr = mock(AttributeMapping.class);
        when(parentAttr.getStateArrayPosition()).thenReturn(7); // arbitrary property index

        // Setter & referencedModelPartType
        Setter setter = mock(Setter.class);
        Type refType = mock(Type.class);
        when(refType.deepCopy(any(), any(SessionFactoryImplementor.class))).thenAnswer(inv -> inv.getArgument(0));

        // Entity entries for each parent (needed in endLoading)
        Object[] loadedState1 = new Object[10];
        Object[] loadedState2 = new Object[10];
        Object[] loadedState3 = new Object[10];
        EntityEntry entry1 = mock(EntityEntry.class);
        EntityEntry entry2 = mock(EntityEntry.class);
        EntityEntry entry3 = mock(EntityEntry.class);
        when(entry1.getLoadedState()).thenReturn(loadedState1);
        when(entry2.getLoadedState()).thenReturn(loadedState2);
        when(entry3.getLoadedState()).thenReturn(loadedState3);
        when(persistenceContext.getEntry(parent1)).thenReturn(entry1);
        when(persistenceContext.getEntry(parent2)).thenReturn(entry2);
        when(persistenceContext.getEntry(parent3)).thenReturn(entry3);

        // internalLoad — the instance "loaded" for the batched entity
        Object loadedInstance = "LoadedEntity";
        when(session.internalLoad(anyString(), any(), anyBoolean(), anyBoolean()))
                .thenReturn(loadedInstance);

        // ── Build the initializer via Unsafe (skip real constructor) ─

        BatchEntitySelectFetchInitializer initializer = allocateInstance(BatchEntitySelectFetchInitializer.class);

        // Set required fields via reflection
        setField(initializer, "owningEntityInitializer", owningInit);  // in AbstractBatch...
        setField(initializer, "parentAttributes", new AttributeMapping[]{ parentAttr });
        setField(initializer, "referencedModelPartSetter", setter);
        setField(initializer, "referencedModelPartType", refType);
        // toOneMapping & affectedByFilter are read in endLoading → loadInstance
        var toOneMapping = mock(org.hibernate.metamodel.mapping.internal.ToOneAttributeMapping.class);
        when(toOneMapping.isInternalLoadNullable()).thenReturn(false);
        setField(initializer, "toOneMapping", toOneMapping);
        setField(initializer, "affectedByFilter", false);

        // ── Build the Data object via Unsafe (skip real constructor) ─

        BatchEntitySelectFetchInitializerData data = allocateInstance(BatchEntitySelectFetchInitializerData.class);
        // InitializerData.rowProcessingState
        setField(data, "rowProcessingState", rowProcessingState);
        // AbstractBatchEntitySelectFetchInitializerData.entityKey
        setField(data, "entityKey", entityKey);
        // state — not INITIALIZED
        data.setState(Initializer.State.RESOLVED);

        // ── Invoke registerResolutionListener 3 times ────────────────
        // Each call adds one ParentInfo to the list for `entityKey`.

        when(owningInit.getTargetInstance(owningData)).thenReturn(parent1);
        invokeRegisterResolutionListener(initializer, data);

        when(owningInit.getTargetInstance(owningData)).thenReturn(parent2);
        invokeRegisterResolutionListener(initializer, data);

        when(owningInit.getTargetInstance(owningData)).thenReturn(parent3);
        invokeRegisterResolutionListener(initializer, data);

        // ── Verify toBatchLoad has 1 key with 3 ParentInfo entries ──

        @SuppressWarnings("unchecked")
        HashMap<EntityKey, ?> toBatchLoad =
                (HashMap<EntityKey, ?>) getField(data, "toBatchLoad");
        assert toBatchLoad != null : "toBatchLoad should not be null";
        assert toBatchLoad.size() == 1 : "Expected 1 entry, got " + toBatchLoad.size();

        List<?> parentInfos = (List<?>) toBatchLoad.values().iterator().next();
        assert parentInfos.size() == 3 : "Expected 3 ParentInfo entries, got " + parentInfos.size();
        System.out.println("✓ toBatchLoad contains 1 EntityKey with 3 ParentInfo entries");

        // ── Invoke endLoading ────────────────────────────────────────

        initializer.endLoading(data);

        // ── Verify side-effects ──────────────────────────────────────

        // setter.set should have been called 3 times (once per ParentInfo)
        verify(setter, times(3)).set(any(), any());
        verify(setter).set(parent1, loadedInstance);
        verify(setter).set(parent2, loadedInstance);
        verify(setter).set(parent3, loadedInstance);
        System.out.println("✓ setter.set() called for all 3 parent instances");

        // loadedState arrays should have the loaded instance at index 7
        assert loadedState1[7] == loadedInstance : "loadedState1[7] not set";
        assert loadedState2[7] == loadedInstance : "loadedState2[7] not set";
        assert loadedState3[7] == loadedInstance : "loadedState3[7] not set";
        System.out.println("✓ loadedState arrays updated at property index 7");

        // toBatchLoad should be nulled out after endLoading
        assert getField(data, "toBatchLoad") == null : "toBatchLoad should be null after endLoading";
        System.out.println("✓ toBatchLoad cleared after endLoading");

        System.out.println("\nAll assertions passed!");
    }

    // ── Reflection / Unsafe helpers ──────────────────────────────────

    @SuppressWarnings("unchecked")
    private static <T> T allocateInstance(Class<T> clazz) throws Exception {
        var unsafeClass = Class.forName("sun.misc.Unsafe");
        var f = unsafeClass.getDeclaredField("theUnsafe");
        f.setAccessible(true);
        var unsafe = f.get(null);
        var allocate = unsafeClass.getMethod("allocateInstance", Class.class);
        return (T) allocate.invoke(unsafe, clazz);
    }

    private static void setField(Object target, String fieldName, Object value) throws Exception {
        Class<?> clazz = target.getClass();
        while (clazz != null) {
            try {
                Field f = clazz.getDeclaredField(fieldName);
                f.setAccessible(true);
                f.set(target, value);
                return;
            } catch (NoSuchFieldException e) {
                clazz = clazz.getSuperclass();
            }
        }
        throw new NoSuchFieldException(fieldName + " not found in " + target.getClass().getName());
    }

    private static Object getField(Object target, String fieldName) throws Exception {
        Class<?> clazz = target.getClass();
        while (clazz != null) {
            try {
                Field f = clazz.getDeclaredField(fieldName);
                f.setAccessible(true);
                return f.get(target);
            } catch (NoSuchFieldException e) {
                clazz = clazz.getSuperclass();
            }
        }
        throw new NoSuchFieldException(fieldName + " not found in " + target.getClass().getName());
    }

    private static void invokeRegisterResolutionListener(
            BatchEntitySelectFetchInitializer initializer,
            BatchEntitySelectFetchInitializerData data) throws Exception {
        var method = BatchEntitySelectFetchInitializer.class
                .getDeclaredMethod("registerResolutionListener", BatchEntitySelectFetchInitializerData.class);
        method.setAccessible(true);
        method.invoke(initializer, data);
    }
}
