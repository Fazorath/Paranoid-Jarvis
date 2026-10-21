"""Resident agent: turns macOS wake/lock/unlock notifications into logged events."""


class Triggers:
    """Tracks lock state and maps raw notifications to event names passed to emit."""

    def __init__(self, emit, locked=False):
        self._emit = emit
        self.locked = locked

    def screen_locked(self):
        self.locked = True

    def screens_woke(self):
        if self.locked:
            self._emit("screen_wake_locked")

    def screen_unlocked(self):
        self.locked = False
        self._emit("unlock")

    def system_woke(self):
        self._emit("wake")


def run():
    """Log login (with a photo), then listen for notifications until killed.

    Run as `python -m paranoid_jarvis.agent` from the repo directory (the plist sets
    WorkingDirectory) so startup_cam_logger and its config are importable.
    """
    import logging

    from AppKit import (NSWorkspace, NSWorkspaceDidWakeNotification,
                        NSWorkspaceScreensDidWakeNotification)
    from Foundation import NSDistributedNotificationCenter, NSObject, NSTimer
    from PyObjCTools import AppHelper
    from Quartz import CGSessionCopyCurrentDictionary

    import startup_cam_logger as cam
    from paranoid_jarvis import event_log

    logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

    def emit(event):
        event_log.append_event(cam.log_path, event, power=event_log.power_source())

    session = CGSessionCopyCurrentDictionary() or {}
    triggers = Triggers(emit, locked=bool(session.get("CGSSessionScreenIsLocked", False)))

    class Observer(NSObject):
        def systemWoke_(self, note):
            triggers.system_woke()

        def screensWoke_(self, note):
            triggers.screens_woke()

        def screenLocked_(self, note):
            triggers.screen_locked()

        def screenUnlocked_(self, note):
            triggers.screen_unlocked()

        def heartbeat_(self, timer):
            emit("heartbeat")

    observer = Observer.new()
    workspace_center = NSWorkspace.sharedWorkspace().notificationCenter()
    workspace_center.addObserver_selector_name_object_(
        observer, "systemWoke:",
        NSWorkspaceDidWakeNotification, None)
    workspace_center.addObserver_selector_name_object_(
        observer, "screensWoke:", NSWorkspaceScreensDidWakeNotification, None)
    distributed_center = NSDistributedNotificationCenter.defaultCenter()
    distributed_center.addObserver_selector_name_object_(
        observer, "screenLocked:", "com.apple.screenIsLocked", None)
    distributed_center.addObserver_selector_name_object_(
        observer, "screenUnlocked:", "com.apple.screenIsUnlocked", None)

    heartbeat_minutes = cam.config.getint("general", "heartbeat_minutes", fallback=15)
    NSTimer.scheduledTimerWithTimeInterval_target_selector_userInfo_repeats_(
        heartbeat_minutes * 60, observer, "heartbeat:", None, True)

    # A camera failure is logged but must not crash the agent, or KeepAlive would
    # relaunch it into another login capture in a loop.
    try:
        cam.main()
    except Exception:
        logging.exception("Login capture failed")

    AppHelper.runConsoleEventLoop(installInterrupt=True)


if __name__ == "__main__":
    run()
