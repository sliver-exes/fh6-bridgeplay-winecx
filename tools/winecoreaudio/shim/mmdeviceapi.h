/* Minimal hand-written shim (widl is not available): only what winecoreaudio.drv's unix side needs. */
#ifndef SHIM_MMDEVICEAPI_H
#define SHIM_MMDEVICEAPI_H
typedef enum EDataFlow { eRender = 0, eCapture = 1, eAll = 2, EDataFlow_enum_count = 3 } EDataFlow;
typedef enum ERole { eConsole = 0, eMultimedia = 1, eCommunications = 2, ERole_enum_count = 3 } ERole;
#endif
