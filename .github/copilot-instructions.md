# Copilot Instructions for AutoRecorder Plugin

## Repository Overview

This repository contains the **AutoRecorder** SourceMod plugin, which automates SourceTV recording based on player count and time of day for Source engine game servers. The plugin provides both automatic recording capabilities and manual admin controls, with a comprehensive API for other plugins to interact with.

### Key Features
- Automatic recording based on player count thresholds
- Time-based recording controls (start/stop hours)
- Manual recording commands for administrators
- Configurable demo storage paths
- Native functions and forwards for plugin integration
- Bot filtering options
- Workshop map compatibility

## Technical Environment

- **Language**: SourcePawn (latest syntax)
- **Platform**: SourceMod 1.11+ (configured for 1.11.0-git6934, but should target 1.12+ for new development)
- **Build System**: SourceKnight 0.2
- **Compiler**: SourcePawn compiler (spcomp) via SourceKnight
- **CI/CD**: GitHub Actions with automated building and releases

## Project Structure

```
addons/sourcemod/
├── scripting/
│   ├── AutoRecorder.sp          # Main plugin source
│   └── include/
│       └── AutoRecorder.inc     # Public API definitions
sourceknight.yaml                # Build configuration
.github/
├── workflows/
│   └── ci.yml                   # CI/CD pipeline
└── dependabot.yml              # Dependency management
```

## Development Workflow

### Building the Plugin

1. **Prerequisites**: SourceKnight build tool (used in CI)
2. **Build Command**: `sourceknight build` (via GitHub Actions)
3. **Output**: Compiled `.smx` files in `/addons/sourcemod/plugins`
4. **Dependencies**: SourceMod 1.11+ headers and includes

### Local Development
- Edit `.sp` files in `addons/sourcemod/scripting/`
- Update `.inc` files for API changes
- Test changes on a local SourceMod development server
- Use GitHub Actions for automated compilation

### Version Management
- Version defined in `AutoRecorder.inc` using semantic versioning
- Update `AutoRecorder_V_MAJOR`, `AutoRecorder_V_MINOR`, `AutoRecorder_V_PATCH`
- Versions are automatically tagged in CI for releases

## Code Style & Standards

### SourcePawn Conventions
```sourcepawn
#pragma semicolon 1
#pragma newdecls required

// Global variables with g_ prefix
Handle g_hConVar = null;
bool g_bIsRecording = false;
int g_iPlayerCount = 0;
char g_sPath[PLATFORM_MAX_PATH];

// Function naming: PascalCase
public void OnPluginStart()
public Action Command_Record(int client, int args)

// Local variables and parameters: camelCase
void CheckStatus()
{
    int iMinClients = g_hMinPlayersStart.IntValue;
    bool bIgnoreBots = g_hIgnoreBots.BoolValue;
}
```

### Key Patterns Used
- **ConVar Management**: All settings use ConVars with change hooks
- **Event-Driven**: Hooks game events (round_start) and client connect/disconnect
- **Timer-Based**: Uses repeating timer for status checks
- **Forward/Native API**: Provides integration points for other plugins
- **Memory Management**: Proper cleanup in OnMapEnd() and CleanUp()

### Best Practices Observed
- Error handling in native functions with `ThrowNativeError`
- Path sanitization for workshop maps (replace `/` and `.` characters)
- Directory creation with proper permissions
- Atomic state management for recording status
- Proper SourceTV client detection

## API Development

### Native Functions Pattern
```sourcepawn
public int Native_FunctionName(Handle hPlugin, int numParams)
{
    // Validate state if needed
    if (!g_bIsRecording)
    {
        ThrowNativeError(SP_ERROR_NATIVE, "Error message");
        return -1;
    }
    
    // Implementation
    return result;
}
```

### Forward Implementation
```sourcepawn
// In AskPluginLoad2()
g_hFwd_OnStartRecord = CreateGlobalForward("AutoRecorder_OnStartRecord", 
    ET_Ignore, Param_String, Param_String, Param_String, Param_Cell, Param_String);

// In function
Call_StartForward(g_hFwd_OnStartRecord);
Call_PushString(param1);
Call_PushCell(param2);
Call_Finish();
```

## Configuration Management

### ConVar Patterns
- All settings prefixed with `sm_autorecord_`
- Use `AutoExecConfig(true)` for automatic config file generation
- Add change hooks for real-time updates: `convar.AddChangeHook(OnConVarChanged)`
- Validate ranges with `true, min, true, max` parameters

### Important ConVars
- `sm_autorecord_enable`: Master enable/disable
- `sm_autorecord_minplayers`: Player count threshold
- `sm_autorecord_path`: Demo storage location
- `sm_autorecord_timestart/timestop`: Time-based controls
- `sm_autorecord_ignorebots`: Bot filtering
- `sm_autorecord_checkstatus`: Automatic status checking

## File Operations

### Path Handling
```sourcepawn
// Always sanitize map names for file paths
ReplaceString(g_sMap, sizeof(g_sMap), "/", "-", false);  // Workshop maps
ReplaceString(g_sMap, sizeof(g_sMap), ".", "_", false);  // Preserve .dem extension

// Directory creation with proper permissions
#define DIRECTORY_PERMISSIONS (FPERM_O_READ|FPERM_O_EXEC | FPERM_G_READ|FPERM_G_EXEC | FPERM_U_READ|FPERM_U_WRITE|FPERM_U_EXEC)
CreateDirectory(path, DIRECTORY_PERMISSIONS);
```

## Testing Considerations

### Manual Testing
- Test on development server with various player counts
- Verify recording starts/stops at configured thresholds
- Test time-based recording controls
- Validate workshop map filename handling
- Test admin commands (`sm_record`, `sm_stoprecord`)

### Integration Testing
- Test with other plugins using the API
- Verify forwards are called correctly
- Test native function error handling
- Validate demo file creation and naming

### Edge Cases to Test
- SourceTV disabled scenarios
- Workshop maps with complex names
- Time zone edge cases (start/stop times)
- Server restart during recording
- Multiple manual recording attempts

## Common Development Tasks

### Adding New ConVars
1. Declare Handle in global scope with `g_h` prefix
2. Create in `OnPluginStart()` with appropriate parameters
3. Add change hook if needed: `convar.AddChangeHook(OnConVarChanged)`
4. Use in logic with `.BoolValue`, `.IntValue`, etc.

### Adding New Native Functions
1. Define in `AutoRecorder.inc` with full documentation
2. Create in `AskPluginLoad2()`: `CreateNative("Name", Native_Handler)`
3. Implement handler with proper error checking
4. Add to optional natives list if not required

### Modifying Recording Logic
- Changes should be made in `CheckStatus()` and `StartRecord()`/`StopRecord()`
- Always maintain state consistency between `g_bIsRecording` and actual SourceTV state
- Update cleanup logic in `CleanUp()` for new state variables
- Consider impact on API consumers (forwards/natives)

## Error Handling Patterns

### ConVar Validation
```sourcepawn
// Validate directory exists, create if needed
if(!DirExists(newValue))
{
    InitDirectory(newValue);
}
```

### Native Function Safety
```sourcepawn
if (!g_bIsRecording)
{
    ThrowNativeError(SP_ERROR_NATIVE, "SourceTV is not recording!");
    return -1;
}
```

### SourceTV State Checking
```sourcepawn
if(g_hTvEnabled.BoolValue && !g_bIsRecording)
{
    // Verify SourceTV client exists
    bool bSourceTV = false;
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientConnected(i) && IsClientSourceTV(i))
        {
            bSourceTV = true;
            break;
        }
    }
    
    if (!bSourceTV)
        return false;
}
```

## Performance Considerations

- **Timer Frequency**: Status check timer runs every 5 seconds (configurable)
- **Player Counting**: Efficient loop through MaxClients with early termination where possible
- **String Operations**: Minimize string operations in frequently called functions
- **Memory**: Proper cleanup prevents memory leaks, especially with Handle types

## Dependencies and Compatibility

- **Minimum SourceMod**: 1.11+ (recommend updating to 1.12+ for new features)
- **Required Extensions**: None beyond core SourceMod
- **Game Compatibility**: Any Source engine game with SourceTV support
- **Operating System**: Cross-platform (Linux, Windows)

## Release Process

1. Update version numbers in `AutoRecorder.inc`
2. Test changes thoroughly on development server
3. Commit changes with descriptive commit message
4. Push to trigger GitHub Actions build
5. Create release tag for distribution (automated via CI)
6. Monitor GitHub Actions for successful compilation

## Troubleshooting Common Issues

### Build Failures
- Check SourceMod version compatibility in `sourceknight.yaml`
- Verify syntax with pragma requirements
- Review Include paths and dependencies

### Recording Issues
- Verify SourceTV is enabled (`tv_enable 1`)
- Check demo path permissions and disk space
- Validate player count logic with bot filtering
- Review time-based logic for timezone considerations

### API Integration Problems
- Ensure native functions are properly registered in `AskPluginLoad2()`
- Check forward parameter types match documentation
- Verify error handling in native implementations