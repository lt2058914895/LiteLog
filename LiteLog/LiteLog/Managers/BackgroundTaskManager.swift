import BackgroundTasks
import CoreData
import os

final class BackgroundTaskManager {
    static let shared = BackgroundTaskManager()

    static let appRefreshTaskId = "com.litelog.app.data-sync"

    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.litelog.app", category: "BackgroundTaskManager")

    private init() {}

    /// 在 App 启动时调用，注册后台任务处理器
    func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.appRefreshTaskId,
            using: nil
        ) { task in
            self.handleAppRefresh(task: task as! BGAppRefreshTask)
        }
        Self.logger.info("后台同步任务已注册")
    }

    /// 调度下一次后台同步（最早 1 小时后执行）
    func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: Self.appRefreshTaskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 60 * 60)

        do {
            try BGTaskScheduler.shared.submit(request)
            #if DEBUG
            Self.logger.debug("后台同步任务已调度，预计 1 小时后执行")
            #endif
        } catch {
            Self.logger.error("后台同步任务调度失败: \(error.localizedDescription)")
        }
    }

    /// 后台同步任务执行逻辑
    private func handleAppRefresh(task: BGAppRefreshTask) {
        Self.logger.info("后台同步任务开始执行")

        // 先调度下一次，确保持续运行
        scheduleAppRefresh()

        // 系统即将回收时间时回调
        task.expirationHandler = {
            Self.logger.warning("后台同步任务时间即将耗尽")
        }

        let context = PersistenceController.shared.viewContext

        Task { @MainActor in
            var success = false

            // 从云端拉取最新数据
            let cloudSynced = await DataSyncManager.shared.syncFromCloud(context: context)
            // 推送本地变更到云端
            await DataSyncManager.shared.syncLocalDataToCloud(context: context)

            success = cloudSynced
            Self.logger.info("后台同步完成，云端拉取 \(cloudSynced ? "成功" : "失败")")
            task.setTaskCompleted(success: success)
        }
    }
}
