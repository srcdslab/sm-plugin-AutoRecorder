#if defined _autorecorder_included
#endinput
#endif
#define _autorecorder_included

/**
 * Called when AutoRecorder plugin becomes available
 *
 * @noreturn
 */
forward void AutoRecorder_OnPluginOK();

/**
 * Called when AutoRecorder plugin becomes unavailable
 *
 * @noreturn
 */
forward void AutoRecorder_OnPluginNotOK();

/**
 * Returns whether the AutoRecorder is currently recording a demo.
 * 
 * @return          True if recording, false otherwise
 */
native bool AutoRecorder_IsDemoRecording();

/**
 * Gets the current demo record count for this map.
 * 
 * @return          Number of demos recorded on current map
 */
native int AutoRecorder_GetDemoRecordCount();

/**
 * Gets the current demo recording tick.
 * 
 * @return          Current recording tick, -1 if not recording
 * @error           If not currently recording
 */
native int AutoRecorder_GetDemoRecordingTick();

/**
 * Gets the timestamp when the current demo started recording.
 * 
 * @return          Unix timestamp when recording started, -1 if not recording
 * @error           If not currently recording
 */
native int AutoRecorder_GetDemoRecordingTime();

/**
 * Gets the map name of the currently recorded demo.
 *
 * @param buffer    Buffer to store the map name.
 * @param maxlen    Maximum length of buffer.
 * @return          1 on success, -1 if not recording.
 * @error           If not currently recording.
 */
native int AutoRecorder_GetDemoRecordingMap(char[] buffer, int maxlen);

/**
 * Gets the filename of the currently recorded demo.
 *
 * @param buffer    Buffer to store the filename.
 * @param maxlen    Maximum length of buffer.
 * @return          1 on success, -1 if not recording.
 * @error           If not currently recording.
 */
native int AutoRecorder_GetDemoRecordingName(char[] buffer, int maxlen);

/**
 * Called when AutoRecord starts recording.
 *
 * @param sPath      The path where the demo is stored
 * @param sMap       The map name related to the demo recording
 * @param sTime      The formatted time when the demo started
 * @param iCount     The current demo record number
 * @param sFileName  The file name of the demo
 * @noreturn
 */
forward void AutoRecorder_OnStartRecord(char[] sPath, char[] sMap, char[] sTime, int iCount, char[]sFileName);

/**
 * Called when AutoRecord stops recording.
 * 
 * @param sPath      The path where the demo is stored
 * @param sMap       The map name related to the demo recording
 * @param sTime      The formatted time when the demo started
 * @param iCount     The current demo record number
 * @param sFileName  The file name of the demo
 * @noreturn
 */
forward void AutoRecorder_OnStopRecord(char[] sPath, char[] sMap, char[] sTime, int iCount, char[]sFileName);

public SharedPlugin __pl_autorecorder =
{
	name = "AutoRecorder",
	file = "AutoRecorder.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_autorecorder_SetNTVOptional()
{
	MarkNativeAsOptional("AutoRecorder_IsDemoRecording");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordCount");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingTick");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingTime");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingMap");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingName");
}
#endif
