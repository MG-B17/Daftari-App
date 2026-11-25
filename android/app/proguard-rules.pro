# Keep Room database implementations (including WorkManager's WorkDatabase_Impl)
# instantiated via reflection during androidx.startup initialization.
-keep class * extends androidx.room.RoomDatabase {
    <init>();
}
-keep class androidx.work.impl.WorkDatabase_Impl {
    <init>(...);
}

# Keep WorkManager workers instantiated via reflection.
-keep class * extends androidx.work.ListenableWorker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
-keep class * extends androidx.work.Worker {
    public <init>(android.content.Context, androidx.work.WorkerParameters);
}
