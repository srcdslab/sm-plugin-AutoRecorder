#if defined _autorecorder_included
#endinput
#endif
#define _autorecorder_included

/**
 * Returns whether the AutoRecorder is currently recording a demo.
 * 
 * @return      True if is recording. False otherwise
 */
native bool AutoRecorder_IsDemoRecording();

/**
 * Get the actual demo record number.
 * 
 * @noreturn
 */
native int AutoRecorder_GetDemoRecordCount();

/**
 * Get the acutal demo recording tick
 * 
 * @noreturn
 */
native int AutoRecorder_GetDemoRecordingTick();

/**
 * Get the Timestamp when demo started.
 * 
 * @noreturn
 */
native int AutoRecorder_GetDemoRecordingTime()

/**
 * Get the Mapname of the currently recorded demo.
 *
 * @param buffer	Buffer to store the mapname in.
 * @param maxlen	Maximal length of the buffer.
 * @noreturn
 */
native int AutoRecorder_GetDemoRecordingMap(char[] buffer, int maxlen);

/**
 * Get the filename of the currently recorded demo.
 *
 * @param buffer	Buffer to store the filename in.
 * @param maxlen	Maximal length of the buffer.
 * @noreturn
 */
native int AutoRecorder_GetDemoRecordingName(char[] buffer, int maxlen);

/**
 * Called when AutoRecord start recording.
 *
 * @param sPath     The path where the demo is stored.
 * @param sMap     	The Mapname related to the demo recording.
 * @param sTime     The Formated time when the demo started.
 * @param iCount    The actual demo record number.
 * @param sFileName	The file name of the demo.
 * @noreturn
 */
forward void AutoRecorder_OnStartRecord(char[] sPath, char[] sMap, char[] sTime, int iCount, char[]sFileName);

/**
 * Called when AutoRecord stop recording.
 * 
 * @param sPath     The path where the demo is stored.
 * @param sMap     	The Mapname related to the demo recording.
 * @param sTime     The Formated time when the demo started.
 * @param iCount    The actual demo record number.
 * @param sFileName	The file name of the demo.
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

public void __pl_autorecorder_SetNTVOptional()
{
	MarkNativeAsOptional("AutoRecorder_IsDemoRecording");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordCount");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingTick");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingTime");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingMap");
	MarkNativeAsOptional("AutoRecorder_GetDemoRecordingName");
}
