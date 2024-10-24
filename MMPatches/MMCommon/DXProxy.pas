unit DXProxy;

interface

uses
  MultiMon, Windows, Messages, SysUtils, Classes, IniFiles, RSSysUtils, RSQ, Math,
  RSCodeHook, DirectDraw, Direct3D, TypInfo, Common, MMCommon, RSResample,
  Graphics, Types;

{$I MMPatchVer.inc}

function MyDirectDrawCreate(lpGUID: PGUID; out lplpDD: IDirectDraw;
    const pUnkOuter: IUnknown): HResult; stdcall;
function DXProxyScaleRect(const r: TRect): TRect;
procedure DXProxyOnResize;
procedure DXProxyDraw(SrcBuf: ptr; info: PDDSurfaceDesc2);
procedure DXProxyDrawCursor(SrcBuf: ptr; info: PDDSurfaceDesc2);

var
  DXProxyRenderW, DXProxyRenderH, DXProxyMipmapCount, DXProxyMipmapCountRes: int;
  DXProxyActive: Boolean;
  DXProxyCursorX, DXProxyCursorY: int;
  DXProxyCursorBmp: TBitmap;
  DXProxyMul, DXProxyShiftX, DXProxyShiftY: ext;
  DXProxyMinW: int = 640;
  DXProxyMinH: int = 480;
  DXProxyTrueColorTexture: Boolean;

implementation

var
  RenderLimX, RenderLimY: int;
  RenderW: int absolute DXProxyRenderW;
  RenderH: int absolute DXProxyRenderH;
  FrontBuffer, BackBuffer, MyBackBuffer, ScaleBuffer: IDirectDrawSurface4;
  Viewport: IDirect3DViewport3;
  Viewport_Def: TD3DViewport2;
  scale, scaleL, scaleT, scaleR, scaleB, scale3D: TRSResampleInfo;
  DrawBufSW: array of Word;
  IsDDraw1: Boolean;

type
  THookedObject = class(TInterfacedObject)
  protected
    class var VMTBlocks: array of ptr;
    FCurVMT: int;
    procedure InitVMT(const Obj: IUnknown; this: IUnknown; PObj: ptr; Size: int);
  public
    function Init(const Obj: IUnknown): IUnknown; virtual;
    class function Hook(var obj): THookedObject;
  end;


  TMyDirectDraw = class(THookedObject, IDirectDraw, IDirectDraw4, IDirect3D3)
  protected
    function Compact: HResult stdcall; dynamic; abstract;
    function CreateClipper(dwFlags: DWORD;
        out lplpDDClipper: IDirectDrawClipper;
        pUnkOuter: IUnknown): HResult stdcall; dynamic; abstract;
    function CreatePalette(dwFlags: DWORD; lpColorTable: Pointer;
        out lplpDDPalette: IDirectDrawPalette;
        pUnkOuter: IUnknown): HResult stdcall; dynamic; abstract;
    function DuplicateSurface(lpDDSurface: IDirectDrawSurface4;
        out lplpDupDDSurface: IDirectDrawSurface4): HResult stdcall; overload; dynamic; abstract;
    function DuplicateSurface(lpDDSurface: IDirectDrawSurface;
        out lplpDupDDSurface: IDirectDrawSurface): HResult stdcall; overload; dynamic; abstract;
    function EnumDisplayModes(dwFlags: DWORD;
        lpDDSurfaceDesc: PDDSurfaceDesc2; lpContext: Pointer;
        lpEnumModesCallback: TDDEnumModesCallback2): HResult stdcall; overload; dynamic; abstract;
    function EnumDisplayModes(dwFlags: DWORD;
        lpDDSurfaceDesc: PDDSurfaceDesc; lpContext: Pointer;
        lpEnumModesCallback: TDDEnumModesCallback): HResult stdcall; overload; dynamic; abstract;
    function EnumSurfaces(dwFlags: DWORD; const lpDDSD: TDDSurfaceDesc2;
        lpContext: Pointer; lpEnumCallback: TDDEnumSurfacesCallback2):
        HResult stdcall; overload; dynamic; abstract;
    function EnumSurfaces(dwFlags: DWORD; const lpDDSD: TDDSurfaceDesc;
        lpContext: Pointer; lpEnumCallback: TDDEnumSurfacesCallback):
        HResult stdcall; overload; dynamic; abstract;
    function FlipToGDISurface: HResult stdcall; dynamic; abstract;
    function GetFourCCCodes(var lpNumCodes: DWORD; lpCodes: PDWORD): HResult stdcall; dynamic; abstract;
    function GetGDISurface(out lplpGDIDDSSurface: IDirectDrawSurface4): HResult stdcall; overload; dynamic; abstract;
    function GetGDISurface(out lplpGDIDDSSurface: IDirectDrawSurface): HResult stdcall; overload; dynamic; abstract;
    function GetMonitorFrequency(out lpdwFrequency: DWORD): HResult stdcall; dynamic; abstract;
    function GetScanLine(out lpdwScanLine: DWORD): HResult stdcall; dynamic; abstract;
    function GetVerticalBlankStatus(out lpbIsInVB: BOOL): HResult stdcall; dynamic; abstract;
    function Initialize(lpGUID: PGUID): HResult stdcall; dynamic; abstract;
    function RestoreDisplayMode: HResult stdcall; dynamic; abstract;
    function SetCooperativeLevel(hWnd: HWND; dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function SetDisplayMode(dwWidth: DWORD; dwHeight: DWORD; dwBPP: DWORD;
        dwRefreshRate: DWORD; dwFlags: DWORD): HResult stdcall; overload; dynamic; abstract;
    function WaitForVerticalBlank(dwFlags: DWORD; hEvent: THandle): HResult stdcall; dynamic; abstract;
    function GetAvailableVidMem(const lpDDSCaps: TDDSCaps2;
        out lpdwTotal, lpdwFree: DWORD): HResult stdcall; dynamic; abstract;
    function GetSurfaceFromDC(hdc: Windows.HDC;
        out lpDDS4: IDirectDrawSurface4): HResult stdcall; dynamic; abstract;
    function RestoreAllSurfaces: HResult stdcall; dynamic; abstract;
    function TestCooperativeLevel: HResult stdcall; dynamic; abstract;
    function GetDeviceIdentifier(out lpdddi: TDDDeviceIdentifier;
        dwFlags: DWORD): HResult stdcall; dynamic; abstract;
  protected
    function EnumDevices(lpEnumDevicesCallback: TD3DEnumDevicesCallback;
        lpUserArg: pointer): HResult stdcall; dynamic; abstract;
    function CreateLight(var lplpDirect3Dlight: IDirect3DLight;
        pUnkOuter: IUnknown): HResult stdcall; dynamic; abstract;
    function CreateMaterial(var lplpDirect3DMaterial3: IDirect3DMaterial3;
        pUnkOuter: IUnknown): HResult stdcall; dynamic; abstract;
    function FindDevice(var lpD3DFDS: TD3DFindDeviceSearch;
        var lpD3DFDR: TD3DFindDeviceResult): HResult stdcall; dynamic; abstract;
    function CreateVertexBuffer(var lpVBDesc: TD3DVertexBufferDesc;
        var lpD3DVertexBuffer: IDirect3DVertexBuffer;
        dwFlags: DWORD; pUnkOuter: IUnknown): HResult stdcall; dynamic; abstract;
    function EnumZBufferFormats(const riidDevice: TRefClsID; lpEnumCallback:
        TD3DEnumPixelFormatsCallback; lpContext: Pointer): HResult stdcall; dynamic; abstract;
    function EvictManagedTextures : HResult stdcall; dynamic; abstract;
  public
    DDraw: IDirectDraw4;
    D3D: IDirect3D3;
    IsMain: Boolean;
    destructor Destroy; override;
    function Init(const Obj: IUnknown): IUnknown; override;
    function GetDisplayMode(out lpDDSurfaceDesc: TDDSurfaceDesc2): HResult stdcall; overload;
    function GetDisplayMode(out lpDDSurfaceDesc: TDDSurfaceDesc): HResult stdcall; overload;
    procedure MakeSurfaceTrueColor(var desc: TDDSurfaceDesc2);
    function CreateSurface(const lpDDSurfaceDesc: TDDSurfaceDesc2;
        out lplpDDSurface: IDirectDrawSurface4;
        pUnkOuter: IUnknown): HResult stdcall; overload;
    function CreateSurface(var lpDDSurfaceDesc: TDDSurfaceDesc;
        out lplpDDSurface: IDirectDrawSurface;
        pUnkOuter: IUnknown): HResult stdcall; overload;
    function CreateViewport(var lplpD3DViewport3: IDirect3DViewport3;
        pUnkOuter: IUnknown): HResult stdcall;
    function CreateDevice(const rclsid: TRefClsID; lpDDS: IDirectDrawSurface4;
        out lplpD3DDevice: IDirect3DDevice3; pUnkOuter: IUnknown): HResult stdcall;
    function SetDisplayMode(dwWidth: DWORD; dwHeight: DWORD;
        dwBpp: DWORD): HResult stdcall; overload;
    function GetCaps(lpDDDriverCaps: PDDCaps; lpDDHELCaps: PDDCaps): HResult stdcall;
  end;


  TMyDevice = class(THookedObject, IDirect3DDevice3)
  protected
    (*** IDirect3DDevice2 methods ***)
    function GetCaps(var lpD3DHWDevDesc: TD3DDeviceDesc;
        var lpD3DHELDevDesc: TD3DDeviceDesc): HResult stdcall; dynamic; abstract;
    function GetStats(var lpD3DStats: TD3DStats): HResult stdcall; dynamic; abstract;
    function EnumTextureFormats(
        lpd3dEnumPixelProc: TD3DEnumPixelFormatsCallback; lpArg: Pointer):
        HResult stdcall; dynamic; abstract;
    function BeginScene: HResult stdcall; dynamic; abstract;
    function EndScene: HResult stdcall; dynamic; abstract;
    function GetDirect3D(var lpD3D: IDirect3D3): HResult stdcall; dynamic; abstract;
    function SetRenderTarget(lpNewRenderTarget: IDirectDrawSurface4)
        : HResult stdcall; dynamic; abstract;
    function GetRenderTarget(var lplpNewRenderTarget: IDirectDrawSurface4)
        : HResult stdcall; dynamic; abstract;
    function Begin_(d3dpt: TD3DPrimitiveType; dwVertexTypeDesc: DWORD;
        dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function BeginIndexed(dptPrimitiveType: TD3DPrimitiveType;
        dwVertexTypeDesc: DWORD; lpvVertices: pointer; dwNumVertices: DWORD;
        dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function Vertex(lpVertex: pointer): HResult stdcall; dynamic; abstract;
    function Index(wVertexIndex: WORD): HResult stdcall; dynamic; abstract;
    function End_(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetRenderState(dwRenderStateType: TD3DRenderStateType;
        var lpdwRenderState): HResult stdcall; dynamic; abstract;
    function SetRenderState(dwRenderStateType: TD3DRenderStateType;
        dwRenderState: DWORD): HResult stdcall; dynamic; abstract;
    function GetLightState(dwLightStateType: TD3DLightStateType;
        var lpdwLightState): HResult stdcall; dynamic; abstract;
    function SetLightState(dwLightStateType: TD3DLightStateType;
        dwLightState: DWORD): HResult stdcall; dynamic; abstract;
    function SetTransform(dtstTransformStateType: TD3DTransformStateType;
        var lpD3DMatrix: TD3DMatrix): HResult stdcall; dynamic; abstract;
    function GetTransform(dtstTransformStateType: TD3DTransformStateType;
        var lpD3DMatrix: TD3DMatrix): HResult stdcall; dynamic; abstract;
    function MultiplyTransform(dtstTransformStateType: TD3DTransformStateType;
        var lpD3DMatrix: TD3DMatrix): HResult stdcall; dynamic; abstract;
    function SetClipStatus(var lpD3DClipStatus: TD3DClipStatus): HResult stdcall; dynamic; abstract;
    function GetClipStatus(var lpD3DClipStatus: TD3DClipStatus): HResult stdcall; dynamic; abstract;
    function DrawIndexedPrimitive(dptPrimitiveType: TD3DPrimitiveType;
        dwVertexTypeDesc: DWORD; const lpvVertices; dwVertexCount: DWORD;
        var lpwIndices: WORD; dwIndexCount, dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function DrawPrimitiveStrided(dptPrimitiveType: TD3DPrimitiveType;
        dwVertexTypeDesc : DWORD;
        var lpVertexArray: TD3DDrawPrimitiveStridedData;
        dwVertexCount, dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function DrawIndexedPrimitiveStrided(dptPrimitiveType: TD3DPrimitiveType;
        dwVertexTypeDesc : DWORD;
        var lpVertexArray: TD3DDrawPrimitiveStridedData; dwVertexCount: DWORD;
        var lpwIndices: WORD; dwIndexCount, dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function DrawPrimitiveVB(dptPrimitiveType: TD3DPrimitiveType;
        lpd3dVertexBuffer: IDirect3DVertexBuffer;
        dwStartVertex, dwNumVertices, dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function DrawIndexedPrimitiveVB(dptPrimitiveType: TD3DPrimitiveType;
        lpd3dVertexBuffer: IDirect3DVertexBuffer; var lpwIndices: WORD;
        dwIndexCount, dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function ComputeSphereVisibility(var lpCenters: TD3DVector;
        var lpRadii: TD3DValue; dwNumSpheres, dwFlags: DWORD;
        var lpdwReturnValues: DWORD): HResult stdcall; dynamic; abstract;
    function GetTexture(dwStage: DWORD; var lplpTexture: IDirect3DTexture2)
        : HResult stdcall; dynamic; abstract;
    function SetTexture(dwStage: DWORD; lplpTexture: IDirect3DTexture2)
        : HResult stdcall; dynamic; abstract;
    function GetTextureStageState(dwStage: DWORD;
        dwState: TD3DTextureStageStateType; var lpdwValue: DWORD): HResult stdcall; dynamic; abstract;
    function SetTextureStageState(dwStage: DWORD;
        dwState: TD3DTextureStageStateType; lpdwValue: DWORD): HResult stdcall; dynamic; abstract;
    function ValidateDevice(var lpdwExtraPasses: DWORD): HResult stdcall; dynamic; abstract;
  public
    Obj: IDirect3DDevice3;
    function Init(const aObj: IUnknown): IUnknown; override;
    function SetCurrentViewport(lpd3dViewport: IDirect3DViewport3): HResult stdcall;
    function AddViewport(lpDirect3DViewport: IDirect3DViewport3): HResult stdcall;
    function DeleteViewport(lpDirect3DViewport: IDirect3DViewport3): HResult stdcall;
    function NextViewport(lpDirect3DViewport: IDirect3DViewport3;
        var lplpAnotherViewport: IDirect3DViewport3; dwFlags: DWORD): HResult stdcall;
    function GetCurrentViewport(var lplpd3dViewport: IDirect3DViewport3)
        : HResult stdcall;
    function DrawPrimitive(dptPrimitiveType: TD3DPrimitiveType;
        dwVertexTypeDesc: DWORD; const lpvVertices;
        dwVertexCount, dwFlags: DWORD): HResult stdcall;
  end;


  TMyViewport = class(THookedObject, IDirect3DViewport3)
  protected
    function Initialize(lpDirect3D: IDirect3D): HResult stdcall; dynamic; abstract;
    function GetViewport(out lpData: TD3DViewport): HResult stdcall; dynamic; abstract;
    function SetViewport(const lpData: TD3DViewport): HResult stdcall; dynamic; abstract;
    function TransformVertices(dwVertexCount: DWORD;
        const lpData: TD3DTransformData; dwFlags: DWORD;
        out lpOffscreen: DWORD): HResult stdcall; dynamic; abstract;
    function LightElements(dwElementCount: DWORD;
        var lpData: TD3DLightData): HResult stdcall; dynamic; abstract;
    function SetBackground(hMat: TD3DMaterialHandle): HResult stdcall; dynamic; abstract;
    function GetBackground(var hMat: TD3DMaterialHandle): HResult stdcall; dynamic; abstract;
    function SetBackgroundDepth(
        lpDDSurface: IDirectDrawSurface): HResult stdcall; dynamic; abstract;
    function GetBackgroundDepth(out lplpDDSurface: IDirectDrawSurface;
        out lpValid: BOOL): HResult stdcall; dynamic; abstract;
    function Clear(dwCount: DWORD; const lpRects: TD3DRect; dwFlags: DWORD):
        HResult stdcall; virtual; abstract;
    function AddLight(lpDirect3DLight: IDirect3DLight): HResult stdcall; dynamic; abstract;
    function DeleteLight(lpDirect3DLight: IDirect3DLight): HResult stdcall; dynamic; abstract;
    function NextLight(lpDirect3DLight: IDirect3DLight;
        out lplpDirect3DLight: IDirect3DLight; dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetViewport2(out lpData: TD3DViewport2): HResult stdcall; dynamic; abstract;
    function SetBackgroundDepth2(
        lpDDSurface: IDirectDrawSurface4): HResult stdcall; dynamic; abstract;
    function GetBackgroundDepth2(out lplpDDSurface: IDirectDrawSurface4;
        out lpValid: BOOL): HResult stdcall; dynamic; abstract;
  public
    Obj: IDirect3DViewport3;
    function Init(const aObj: IUnknown): IUnknown; override;
    function Clear2(dwCount: DWORD; const lpRects: TD3DRect; dwFlags: DWORD;
        dwColor: DWORD; dvZ: TD3DValue; dwStencil: DWORD): HResult stdcall;
    function SetViewport2(const lpData: TD3DViewport2): HResult stdcall;
  end;


  TMySurface = class(THookedObject, IDirectDrawSurface4)
  protected
    (*** IDirectDrawSurface methods ***)
    function AddAttachedSurface(lpDDSAttachedSurface: IDirectDrawSurface4) :
        HResult stdcall; dynamic; abstract;
    function AddOverlayDirtyRect(const lpRect: TRect): HResult stdcall; dynamic; abstract;
    function Blt(lpDestRect: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; dynamic; abstract;
    function BltBatch(const lpDDBltBatch: TDDBltBatch; dwCount: DWORD;
        dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function BltFast(dwX: DWORD; dwY: DWORD;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwTrans: DWORD): HResult stdcall; dynamic; abstract;
    function DeleteAttachedSurface(dwFlags: DWORD;
        lpDDSAttachedSurface: IDirectDrawSurface4): HResult stdcall; dynamic; abstract;
    function EnumAttachedSurfaces(lpContext: Pointer;
        lpEnumSurfacesCallback: TDDEnumSurfacesCallback2): HResult stdcall; dynamic; abstract;
    function EnumOverlayZOrders(dwFlags: DWORD; lpContext: Pointer;
        lpfnCallback: TDDEnumSurfacesCallback2): HResult stdcall; dynamic; abstract;
    function Flip(lpDDSurfaceTargetOverride: IDirectDrawSurface4;
        dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetAttachedSurface(const lpDDSCaps: TDDSCaps2;
        out lplpDDAttachedSurface: IDirectDrawSurface4): HResult stdcall; dynamic; abstract;
    function GetBltStatus(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetCaps(out lpDDSCaps: TDDSCaps2): HResult stdcall; dynamic; abstract;
    function GetClipper(out lplpDDClipper: IDirectDrawClipper): HResult stdcall; dynamic; abstract;
    function GetColorKey(dwFlags: DWORD; out lpDDColorKey: TDDColorKey) :
        HResult stdcall; dynamic; abstract;
    function GetDC(out lphDC: HDC): HResult stdcall; dynamic; abstract;
    function GetFlipStatus(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetOverlayPosition(out lplX, lplY: Longint): HResult stdcall; dynamic; abstract;
    function GetPalette(out lplpDDPalette: IDirectDrawPalette): HResult stdcall; dynamic; abstract;
    function GetPixelFormat(out lpDDPixelFormat: TDDPixelFormat): HResult stdcall; dynamic; abstract;
    function GetSurfaceDesc(out lpDDSurfaceDesc: TDDSurfaceDesc2): HResult stdcall; dynamic; abstract;
    function Initialize(lpDD: IDirectDraw;
        out lpDDSurfaceDesc: TDDSurfaceDesc2): HResult stdcall; dynamic; abstract;
    function IsLost: HResult stdcall; dynamic; abstract;
    function Lock(lpDestRect: PRect;
        out lpDDSurfaceDesc: TDDSurfaceDesc2; dwFlags: DWORD;
        hEvent: THandle): HResult stdcall; dynamic; abstract;
    function ReleaseDC(hDC: Windows.HDC): HResult stdcall; dynamic; abstract;
    function _Restore: HResult stdcall; dynamic; abstract;
    function SetClipper(lpDDClipper: IDirectDrawClipper): HResult stdcall; dynamic; abstract;
    function SetColorKey(dwFlags: DWORD; lpDDColorKey: PDDColorKey) :
        HResult stdcall; dynamic; abstract;
    function SetOverlayPosition(lX, lY: Longint): HResult stdcall; dynamic; abstract;
    function SetPalette(lpDDPalette: IDirectDrawPalette): HResult stdcall; dynamic; abstract;
    function Unlock(lpRect: PRect): HResult stdcall; dynamic; abstract;
    function UpdateOverlay(lpSrcRect: PRect;
        lpDDDestSurface: IDirectDrawSurface4; lpDestRect: PRect;
        dwFlags: DWORD; lpDDOverlayFx: PDDOverlayFX): HResult stdcall; dynamic; abstract;
    function UpdateOverlayDisplay(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function UpdateOverlayZOrder(dwFlags: DWORD;
        lpDDSReference: IDirectDrawSurface4): HResult stdcall; dynamic; abstract;
    (*** Added in the v2 interface ***)
    function GetDDInterface(out lplpDD: IUnknown): HResult stdcall; dynamic; abstract;
    function PageLock(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function PageUnlock(dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    (*** Added in the V3 interface ***)
    function SetSurfaceDesc(const lpddsd2: TDDSurfaceDesc2; dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    (*** Added in the v4 interface ***)
    function SetPrivateData(const guidTag: TGUID; lpData: Pointer;
        cbSize: DWORD; dwFlags: DWORD): HResult stdcall; dynamic; abstract;
    function GetPrivateData(const guidTag: TGUID; lpBuffer: Pointer;
        var lpcbBufferSize: DWORD): HResult stdcall; dynamic; abstract;
    function FreePrivateData(const guidTag: TGUID): HResult stdcall; dynamic; abstract;
    function GetUniquenessValue(out lpValue: DWORD): HResult stdcall; dynamic; abstract;
    function ChangeUniquenessValue: HResult stdcall; dynamic; abstract;
  public
    Surf: IDirectDrawSurface4;
    function Init(const Obj: IUnknown): IUnknown; override;
  end;


  TMyBackBufferD3D = class(TMySurface, IDirectDrawSurface4)
  public
    function Blt(r: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; reintroduce;
  end;


  TMyFrontBufferD3D = class(TMySurface, IDirectDrawSurface4)
  public
    function GetPixelFormat(out fmt: TDDPixelFormat): HResult stdcall; reintroduce;
    function Blt(lpDestRect: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; reintroduce;
  end;


  TMySurfaceSW = class(TMySurface, IDirectDrawSurface4)
  public
    function Lock(lpDestRect: PRect;
        out lpDDSurfaceDesc: TDDSurfaceDesc2; dwFlags: DWORD;
        hEvent: THandle): HResult stdcall; reintroduce;
    function Blt(lpDestRect: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; reintroduce;
    function BltBatch(const lpDDBltBatch: TDDBltBatch; dwCount: DWORD;
        dwFlags: DWORD): HResult stdcall; reintroduce; virtual; abstract;
    function BltFast(dwX: DWORD; dwY: DWORD;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwTrans: DWORD): HResult stdcall; reintroduce;
    function AddAttachedSurface(lpDDSAttachedSurface: IDirectDrawSurface4) :
        HResult stdcall; reintroduce;
    function DeleteAttachedSurface(dwFlags: DWORD;
        lpDDSAttachedSurface: IDirectDrawSurface4): HResult stdcall; reintroduce;
    function Flip(lpDDSurfaceTargetOverride: IDirectDrawSurface4;
        dwFlags: DWORD): HResult stdcall; reintroduce;
  end;


  TMyFrontBufferSW = class(TMySurfaceSW, IDirectDrawSurface4)
  public
    function GetPixelFormat(out fmt: TDDPixelFormat): HResult stdcall; reintroduce;
    function Blt(lpDestRect: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; reintroduce;
  end;


  TMyBackBufferSW = class(TMySurfaceSW, IDirectDrawSurface4)
  public
    function Lock(lpDestRect: PRect;
        out lpDDSurfaceDesc: TDDSurfaceDesc2; dwFlags: DWORD;
        hEvent: THandle): HResult stdcall; reintroduce;
    function Unlock(lpRect: PRect): HResult stdcall; reintroduce;
    function Blt(lpDestRect: PRect;
        lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
        dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult stdcall; reintroduce;
  end;


{ functions }

function GetRaw(const p: IUnknown):ptr;
begin
  Result:= pptr(PChar(p) + pint(PPChar(p)^ - 4)^)^;
end;

procedure MyPixelFormat(var fmt: TDDPixelFormat; res: HRESULT);
const
  str = #32#0#0#0#64#0#0#0#0#0#0#0#16#0#0#0#0#248#0#0#224#7#0#0#31#0#0#0#0#0#0#0;
begin
  if (res <> DD_OK) or (fmt.dwRGBBitCount <> 16) then
    CopyMemory(@fmt, PChar(str), length(str));
end;

function BaseScaleRect(const r: TRect): TRect;
begin
  NeedScreenWH;
  with Result do
  begin
    Left:= r.Left*RenderW div SW;
    Right:= r.Right*RenderW div SW;
    Top:= r.Top*RenderH div SH;
    Bottom:= r.Bottom*RenderH div SH;
  end;
end;


function DXProxyScaleRect(const r: TRect): TRect;
begin
  if _Windowed^ and (DXProxyMul <> 0) then
    with Result do
    begin
      Left:= Round(r.Left*DXProxyMul + DXProxyShiftX);
      Right:= Round(r.Right*DXProxyMul + DXProxyShiftX);
      Top:= Round(r.Top*DXProxyMul + DXProxyShiftY);
      Bottom:= Round(r.Bottom*DXProxyMul + DXProxyShiftY);
    end else
      Result:= BaseScaleRect(r);
end;

var
  ScaleRect_Rect: TRect;

procedure ScaleRect(var r: PRect);
begin
  if r = nil then  exit;
  ScaleRect_Rect:= BaseScaleRect(r^);
  r:= @ScaleRect_Rect;
end;

procedure CalcSize1(var rw, rh: int; fw, fh, w1, w2, h1, h2: int);
begin
  rw:= fw div ((fw - 1) div w2 + 1);
  rh:= RDiv(rw*fh, fw);
  if (rw < w1) or (rh < h1) then
  begin
    rw:= w2;
    rh:= max(h1, RDiv(rw*fh, fw));
  end;
end;

procedure CalcRenderSize;
var
  r: TRect;
begin
  NeedScreenWH;
  GetClientRect(_MainWindow^, r);
  RenderW:= r.Right;
  RenderH:= r.Bottom;
  if (DXProxyMul <> 0) and ((RenderW > RenderLimX) or (RenderH > RenderLimY)) then
    if RenderW*RenderLimY >= RenderH*RenderLimX then
      CalcSize1(RenderW, RenderH, r.Right, r.Bottom, DXProxyMinW, RenderLimX, DXProxyMinH, RenderLimY)
    else
      CalcSize1(RenderH, RenderW, r.Bottom, r.Right, DXProxyMinH, RenderLimY, DXProxyMinW, RenderLimX);
  if RenderW > RenderLimX then
    RenderW:= max(DXProxyMinW, RenderW div ((RenderW - 1) div RenderLimX + 1));
  if RenderH > RenderLimY then
    RenderH:= max(DXProxyMinH, RenderH div ((RenderH - 1) div RenderLimY + 1));
  RenderW:= min(RenderW, RenderLimX);
  RenderH:= min(RenderH, RenderLimY);
end;

// Direct3D 7 fails with an error if any surface dimention is over 2048.
// It's a bug intentionally introduced by MS.
// fix is from https://github.com/UCyborg/LegacyD3DResolutionHack
var
  Direct3DFixed: Boolean;

procedure FixDirect3D;
const
  code = #$B8#0#8#0#0#$39;
  hk0: TRSHookInfo = (new: $7fffffff; t: RSht4);
var
  hk: TRSHookInfo;
  p, sz: uint;
begin
  p:= RSWin32Check(GetModuleHandle('d3dim.dll'));
  with PImageNtHeaders(p + uint(PImageDosHeader(p)._lfanew))^ do
  begin
    sz:= OptionalHeader.SizeOfCode - SizeOf(code);
    inc(p, OptionalHeader.BaseOfCode);
  end;
  hk:= hk0;
  for p:= p to p + sz do
    if (pint(p)^ = pint(@code[1])^) and (pword(p + 4)^ = pword(@code[5])^) then
    begin
      hk.p:= p + 1;
      RSApplyHook(hk);
    end;
  Direct3DFixed:= true;
end;

function EnumMonProc(hm: HMONITOR; dc: HDC; r: PRect; Data: Pointer): Boolean; stdcall;
var
  a: TMonitorInfo;
begin
  FillChar(a, SizeOf(a), 0);
  a.cbSize:= SizeOf(a);
  GetMonitorInfo(hm, @a);
  inc(RenderLimX, RectW(a.rcMonitor));
  inc(RenderLimY, RectH(a.rcMonitor));
  Result:= true;
end;

procedure CalcRenderLim;
begin
  RenderLimX:= 0;
  RenderLimY:= 0;
  EnumDisplayMonitors(0, nil, @EnumMonProc, 0);
  RenderLimX:= max(RenderLimX, GetSystemMetrics(SM_CXSCREEN));
  RenderLimY:= max(RenderLimY, GetSystemMetrics(SM_CYSCREEN));
  if RenderMaxWidth >= 640 then
    RenderLimX:= RenderMaxWidth;
  if RenderMaxHeight >= 480 then
    RenderLimY:= RenderMaxHeight;
  CalcRenderSize;
end;

var
  DDrawCreate: function(lpGUID: PGUID; out lplpDD: IDirectDraw;
    pUnkOuter: IUnknown): HResult; stdcall;

function MyDirectDrawCreate(lpGUID: PGUID; out lplpDD: IDirectDraw;
    const pUnkOuter: IUnknown): HResult; stdcall;
var
  path: array[0..MAX_PATH] of char;
begin
  // Bypass dgVoodoo substitute DDraw.dll
  if @DDrawCreate = nil then
    if SystemDDraw then
    begin
      GetSystemDirectory(@path[0], SizeOf(path));
      if RSLoadProc(@DDrawCreate, IncludeTrailingPathDelimiter(path) + 'ddraw.dll', 'DirectDrawCreate') = 0 then
        @DDrawCreate:= @DirectDrawCreate;
    end else
      @DDrawCreate:= @DirectDrawCreate;
  Result:= DDrawCreate(lpGUID, lplpDD, pUnkOuter);
  DXProxyActive:= (GetWindowLong(_MainWindow^, GWL_STYLE) and WS_BORDER <> 0) or
     BorderlessFullscreen or not _Windowed^;
  DXProxyActive:= DXProxyActive and (GetDeviceCaps(GetDC(0), BITSPIXEL) = 32);
  if DXProxyActive then
    TMyDirectDraw.Hook(lplpDD);
end;

procedure DXProxyOnResize;
begin
  if DXProxyActive and (RenderLimX <> 0) then
    CalcRenderSize;
  if Viewport_Def.dwSize <> 0 then
    Viewport.SetViewport2(Viewport_Def);
end;

procedure DrawCursor(surf: PChar; pitch: int);
var
  p1, p2: PChar;
  x, y, w, h, d1, d2: int;
  k, trans: int;
begin
  w:= DXProxyCursorBmp.Width;
  h:= DXProxyCursorBmp.Height;
  p1:= DXProxyCursorBmp.ScanLine[0];
  d1:= PChar(DXProxyCursorBmp.ScanLine[1]) - p1 - 4*w;
  p2:= surf + pitch*DXProxyCursorY + 4*DXProxyCursorX;
  d2:= pitch - 4*w;
  trans:= pint(p1)^;
  for y := 1 to h do
  begin
    for x := 1 to w do
    begin
      k:= pint(p1)^;
      if k <> trans then
        pint(p2)^:= k;
      inc(p1, 4);
      inc(p2, 4);
    end;
    inc(p1, d1);
    inc(p2, d2);
  end;
end;

var
  FPSUp, FPSTime: uint;

procedure FPS;
var
  k: uint;
begin
  inc(FPSUp);
  k:= GetTickCount;
  if k < FPSTime then  exit;
  zM(FPSUp);
  FPSUp:= 0;
  FPSTime:= k + 1000;
end;

procedure DXProxyDraw(SrcBuf: ptr; info: PDDSurfaceDesc2);
var
  scale2: TRSResampleInfo;
  r: TRect;
  d: int;
begin
  //FPS;
  with Options, RenderRect do
    if (_ScreenW^ > 640) and (Right < _RenderRect.Right) or
       (_ScreenH^ > 480) and (Bottom < _RenderRect.Bottom + 1) then
    begin
      // MM7ResTool support
      RenderRect:= Rect(0, 0, _ScreenW^, _ScreenH^);
      RenderBottomPixel:= _ScreenH^ - 1;
    end;
  if (scale.DestW <> RenderW) or (scale.DestH <> RenderH) then
  begin
    RSSetResampleParams(ScalingParam1, ScalingParam2);
    scale.Init(_ScreenW^, _ScreenH^, max(RenderW, _ScreenW^), max(RenderH, _ScreenH^));
    d:= IfThen(_IsD3D^, 1, -1);
    with Options.RenderRect do
      r:= DXProxyScaleRect(Rect(max(0, Left - d), max(0, Top - d), Right + d, Bottom + d));
    r.Right:= min(r.Right, RenderW);
    r.Bottom:= min(r.Bottom, RenderH);
    if not _IsD3D^ then
    begin
      RSSetResampleParams(1.11);
      scale2.Init(_ScreenW^, _ScreenH^, max(RenderW, _ScreenW^), max(RenderH, _ScreenH^));
      scale3D:= scale2.ScaleRect(r);
    end else
      scale3D:= scale.ScaleRect(r);
    scaleT:= scale.ScaleRect(Rect(0, 0, RenderW, r.Top));
    scaleB:= scale.ScaleRect(Rect(0, r.Bottom, RenderW, RenderH));
    scaleL:= scale.ScaleRect(Rect(0, r.Top, r.Left, r.Bottom));
    scaleR:= scale.ScaleRect(Rect(r.Right, r.Top, RenderW, r.Bottom));
  end;
  if _IsD3D^ or SmoothScaleViewSW and (_CurrentScreen^ = 0) and
     (_MainMenuCode^ < 0) and not _RightButtonPressed^ then
  begin
    RSResample16(scaleT, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
    RSResample16(scaleL, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
    if _IsD3D^ then
      RSResampleTrans16_NoAlpha(scale3D, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch, _GreenMask^ + _BlueMask^)
    else
      RSResample16(scale3D, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
    RSResample16(scaleR, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
    RSResample16(scaleB, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
  end else
    RSResample16(scale, SrcBuf, _ScreenW^*2, info.lpSurface, info.lPitch);
  DXProxyDrawCursor(SrcBuf, info);
end;

procedure DXProxyDrawCursor(SrcBuf: ptr; info: PDDSurfaceDesc2);
begin
  if DXProxyCursorX > 0 then
    DrawCursor(info.lpSurface, info.lPitch);
  DXProxyCursorX:= 0;
end;

const
  TransColor32 = $FFFF;
var
  DrawSurf, DrawSurfNext: IDirectDrawSurface4;

procedure FillTrans(const desc: TDDSurfaceDesc2);
var
  p: PChar;
  i: int;
begin
  p:= desc.lpSurface;
  for i := 0 to desc.dwHeight - 1 do
  begin
    RSFillDWord(p, desc.dwWidth, TransColor32);
    inc(p, desc.lPitch);
  end;
end;

{ THookedObject }

procedure PassThrough;
asm
  mov ecx, [esp + 4]
  mov edx, [eax + 4]  // Off
  mov ecx, [ecx + edx]
  mov [esp + 4], ecx
  jmp [eax]  // objVMT[i]
end;

// this fully implementation-dependant way is the only one I could come up with
function IsDyna(p: PChar): Boolean;
begin
  Result:= false;
  if pint(p)^ <> $04244483 then  exit;
  inc(p, 5);
  if pint(p)^ <> $0424448B then  exit;
  inc(p, 4);
  if pword(p)^ <> $BA66 then  exit;
  inc(p, 4);
  Result:= (p^ = #$E8);
end;

function DoInitVMT(obj, this: PPointerArray; Off, Size: int): PPointerArray;
const
  HookBase: TRSHookInfo = (newp: @PassThrough; t: RShtCodePtrStore);
var
  hook: TRSHookInfo;
  m: PPoint;
  i: int;
begin
  Result:= AllocMem(Size + 4);
  Result[0]:= ptr(Off);
  Result:= @Result[1];
  m:= AllocMem(Size*2);
  hook:= HookBase;
  for i:= 0 to Size div 4 - 1 do
    if IsDyna(this[i]) then
    begin
      m.X:= int(obj[i]);
      m.Y:= Off;
      Result[i]:= m;
      hook.p:= int(@Result[i]);
      RSApplyHook(hook);
      inc(m);
    end else
      Result[i]:= this[i];
end;

class function THookedObject.Hook(var obj): THookedObject;
begin
  Result:= Create;
  IUnknown(obj):= Result.Init(IUnknown(obj));
end;

function THookedObject.Init(const Obj: IUnknown): IUnknown;
begin
  Result:= nil;
end;

procedure THookedObject.InitVMT(const Obj: IUnknown; this: IUnknown; PObj: ptr; Size: int);
begin
  IUnknown(PObj^):= Obj;
  if FCurVMT >= length(VMTBlocks) then
  begin
    SetLength(VMTBlocks, FCurVMT + 1);
    VMTBlocks[FCurVMT]:= DoInitVMT(pptr(Obj)^, pptr(this)^, PObj - PChar(this), Size);
  end;
  pptr(this)^:= VMTBlocks[FCurVMT];
  inc(FCurVMT);
end;

{ TMyDirectDraw }

function TMyDirectDraw.CreateDevice(const rclsid: TRefClsID;
  lpDDS: IDirectDrawSurface4; out lplpD3DDevice: IDirect3DDevice3;
  pUnkOuter: IInterface): HResult;
label retry;
begin
retry:
  if lpDDS = MyBackBuffer then
    Result:= D3D.CreateDevice(rclsid, BackBuffer, lplpD3DDevice, pUnkOuter)
  else
    Result:= D3D.CreateDevice(rclsid, lpDDS, lplpD3DDevice, pUnkOuter);
  if (Result <> DD_OK) and _IsD3D^ and (max(RenderLimX, RenderLimY) > 2048) and not Direct3DFixed and not UseVoodoo then
  begin
    FixDirect3D;
    goto retry;
  end;
  if Result = DD_OK then
    TMyDevice.Hook(lplpD3DDevice);
end;

function TMyDirectDraw.CreateSurface(var lpDDSurfaceDesc: TDDSurfaceDesc;
  out lplpDDSurface: IDirectDrawSurface; pUnkOuter: IInterface): HResult;
var
  d: TDDSurfaceDesc2;
begin
  IsDDraw1:= true;
  CopyMemory(@d, @lpDDSurfaceDesc, lpDDSurfaceDesc.dwSize);
  d.dwSize:= SizeOf(d);
  d.ddsCaps.dwCaps2:= 0;
  d.ddsCaps.dwCaps3:= 0;
  d.ddsCaps.dwCaps4:= 0;
  d.dwTextureStage:= 0;
  Result:= CreateSurface(d, IDirectDrawSurface4(lplpDDSurface), pUnkOuter);
end;

function TMyDirectDraw.CreateSurface(const lpDDSurfaceDesc: TDDSurfaceDesc2;
  out lplpDDSurface: IDirectDrawSurface4; pUnkOuter: IInterface): HResult;
var
  desc: TDDSurfaceDesc2;
  NeedScaling: Boolean;
begin
  with lpDDSurfaceDesc do
    if (DXProxyMipmapCount > 0) and (dwMipMapCount > 1) and (dwFlags and DDSD_MIPMAPCOUNT <> 0) then
    begin
      desc:= lpDDSurfaceDesc;
      if DXProxyTrueColorTexture then
        MakeSurfaceTrueColor(desc);
      desc.dwMipMapCount:= min(desc.dwMipMapCount, DXProxyMipmapCount);
      DXProxyMipmapCountRes:= desc.dwMipMapCount;
      Result:= DDraw.CreateSurface(desc, lplpDDSurface, pUnkOuter);
      if Result <> DD_OK then
      begin
        desc.dwFlags:= desc.dwFlags and not DDSD_MIPMAPCOUNT;
        Result:= DDraw.CreateSurface(desc, lplpDDSurface, pUnkOuter);
      end;
      DXProxyMipmapCount:= 0;
      exit;
    end;

  // back buffer or Z buffer
  with lpDDSurfaceDesc do
    if _IsD3D^ then
      NeedScaling:= (ddsCaps.dwCaps = $2040) and (dwFlags = 7) or
        (ddsCaps.dwCaps = $20000) and (dwFlags = $1007)
    else
      NeedScaling:= (ddsCaps.dwCaps = $840) and (dwFlags = 7);

  // back buffer or Z buffer
  if NeedScaling then
  begin
    if lpDDSurfaceDesc.dwFlags = 7 then  // back buffer
      CalcRenderLim;
    desc:= lpDDSurfaceDesc;
    desc.dwWidth:= RenderLimX;
    desc.dwHeight:= RenderLimY;
    Result:= DDraw.CreateSurface(desc, lplpDDSurface, pUnkOuter);
    if (lpDDSurfaceDesc.dwFlags = 7) and (Result = DD_OK) then
    begin
      BackBuffer:= lplpDDSurface;
      if _IsD3D^ then
        TMyBackBufferD3D.Hook(lplpDDSurface)
      else
        TMyBackBufferSW.Hook(lplpDDSurface);
      MyBackBuffer:= lplpDDSurface;
      IsMain:= true;
    end else if not _IsD3D^ and (Result = DD_OK) then
      TMySurfaceSW.Hook(lplpDDSurface);
    exit;
  end;

  if DXProxyTrueColorTexture then
  begin
    desc:= lpDDSurfaceDesc;
    MakeSurfaceTrueColor(desc);
    Result:= DDraw.CreateSurface(desc, lplpDDSurface, pUnkOuter);
  end else
    Result:= DDraw.CreateSurface(lpDDSurfaceDesc, lplpDDSurface, pUnkOuter);

  // front buffer
  if (lpDDSurfaceDesc.ddsCaps.dwCaps and DDSCAPS_PRIMARYSURFACE <> 0) and (Result = DD_OK) then
  begin
    FrontBuffer:= lplpDDSurface;
    if _IsD3D^ then
      TMyFrontBufferD3D.Hook(lplpDDSurface)
    else
      TMyFrontBufferSW.Hook(lplpDDSurface)
  end else if not _IsD3D^ and (Result = DD_OK) then
    TMySurfaceSW.Hook(lplpDDSurface);
end;

function TMyDirectDraw.CreateViewport(var lplpD3DViewport3: IDirect3DViewport3;
  pUnkOuter: IInterface): HResult;
begin
  Result:= D3D.CreateViewport(lplpD3DViewport3, pUnkOuter);
  if Result <> DD_OK then  exit;
  TMyViewport.Hook(lplpD3DViewport3);
  Viewport:= lplpD3DViewport3;
end;

destructor TMyDirectDraw.Destroy;
begin
  if not IsMain then  exit;
  FrontBuffer:= nil;
  BackBuffer:= nil;
  MyBackBuffer:= nil;
  ScaleBuffer:= nil;
  Viewport:= nil;
  Viewport_Def.dwSize:= 0;
end;

function TMyDirectDraw.GetCaps(lpDDDriverCaps, lpDDHELCaps: PDDCaps): HResult;
begin
  Result:= DDraw.GetCaps(lpDDDriverCaps, lpDDHELCaps);
  // To use buffer instead of draw surface that's painted with 5 Blt's:
  // remove DDCAPS_BLT from dwSVBCaps or remove DDCKEYCAPS_SRCBLT from dwSVBCKeyCaps
  lpDDDriverCaps.dwSVBCKeyCaps:= lpDDDriverCaps.dwSVBCKeyCaps and not DDCKEYCAPS_SRCBLT;
end;

function TMyDirectDraw.GetDisplayMode(
  out lpDDSurfaceDesc: TDDSurfaceDesc): HResult;
var
  d: TDDSurfaceDesc2;
begin
  d.dwSize:= SizeOf(d);
  Result:= GetDisplayMode(d);
  d.dwSize:= SizeOf(TDDSurfaceDesc);
  CopyMemory(@lpDDSurfaceDesc, @d, d.dwSize);
end;

function TMyDirectDraw.GetDisplayMode(
  out lpDDSurfaceDesc: TDDSurfaceDesc2): HResult;
begin
  Result:= DDraw.GetDisplayMode(lpDDSurfaceDesc);
  MyPixelFormat(lpDDSurfaceDesc.ddpfPixelFormat, Result);
end;

function TMyDirectDraw.Init(const Obj: IInterface): IUnknown;
begin
  Result:= self as IDirectDraw;
  InitVMT(Obj as IDirectDraw4, self as IDirectDraw4, @DDraw, $70);
  InitVMT(Obj as IDirect3D3, self as IDirect3D3, @D3D, $30);
  InitVMT(DDraw, Result, @DDraw, $70 - 5*4);
end;

procedure TMyDirectDraw.MakeSurfaceTrueColor(var desc: TDDSurfaceDesc2);
begin
  with desc.ddpfPixelFormat do
  begin
    dwRGBBitCount:= 32;
    dwRBitMask:= $FF0000;
    dwGBitMask:= $FF00;
    dwBBitMask:= $FF;
    dwRGBAlphaBitMask:= $FF000000;
  end;
  DXProxyTrueColorTexture:= false;
end;

function TMyDirectDraw.SetDisplayMode(dwWidth, dwHeight, dwBpp: DWORD): HResult;
begin
  Result:= DDraw.SetDisplayMode(dwWidth, dwHeight, dwBpp, 0, 0);
end;

{ TMyViewport }

function TMyViewport.Clear2(dwCount: DWORD; const lpRects: TD3DRect; dwFlags,
  dwColor: DWORD; dvZ: TD3DValue; dwStencil: DWORD): HResult;
var
  r: TD3DRect;
begin
  r.x1:= 0;
  r.y1:= 0;
  r.x2:= RenderW;
  r.y2:= RenderH;
  Result:= Obj.Clear2(1, r, dwFlags, dwColor, dvZ, dwStencil);
//  Result:= Obj.Clear2(dwCount, lpRects, dwFlags, dwColor, dvZ, dwStencil);
end;

function TMyViewport.Init(const aObj: IInterface): IUnknown;
begin
  Result:= self as IDirect3DViewport3;
  InitVMT(aObj as IDirect3DViewport3, Result, @Obj, 21*4);
end;

function TMyViewport.SetViewport2(const lpData: TD3DViewport2): HResult;
begin
  Viewport_Def:= lpData;
  Viewport_Def.dwWidth:= RenderW;
  Viewport_Def.dwHeight:= RenderH;
  Result:= Obj.SetViewport2(Viewport_Def);
end;

{ TMyDevice }

function TMyDevice.AddViewport(lpDirect3DViewport: IDirect3DViewport3): HResult;
begin
  Result:= Obj.AddViewport(IDirect3DViewport3(GetRaw(lpDirect3DViewport)));
end;

function TMyDevice.DeleteViewport(
  lpDirect3DViewport: IDirect3DViewport3): HResult;
begin
  Result:= Obj.DeleteViewport(IDirect3DViewport3(GetRaw(lpDirect3DViewport)));
end;

var
  VertexBuf: array of TD3DTLVertex;

function TMyDevice.DrawPrimitive(dptPrimitiveType: TD3DPrimitiveType;
  dwVertexTypeDesc: DWORD; const lpvVertices; dwVertexCount,
  dwFlags: DWORD): HResult;
var
  i: int;
begin
  if int(dwVertexCount) > length(VertexBuf) then
    SetLength(VertexBuf, dwVertexCount*2);
  CopyMemory(@VertexBuf[0], @lpvVertices, dwVertexCount*SizeOf(VertexBuf[0]));
  for i:= 0 to dwVertexCount - 1 do
    if DXProxyMul <> 0 then
    begin
      VertexBuf[i].sx:= VertexBuf[i].sx*DXProxyMul + DXProxyShiftX;
      VertexBuf[i].sy:= VertexBuf[i].sy*DXProxyMul + DXProxyShiftY;
    end else
    begin
      VertexBuf[i].sx:= VertexBuf[i].sx*RenderW/_ScreenW^;
      VertexBuf[i].sy:= VertexBuf[i].sy*RenderH/_ScreenH^;
    end;
  Result:= Obj.DrawPrimitive(dptPrimitiveType,
    dwVertexTypeDesc, VertexBuf[0], dwVertexCount, dwFlags);
end;

function TMyDevice.GetCurrentViewport(
  var lplpd3dViewport: IDirect3DViewport3): HResult;
begin
  Assert(false);
  Result:= DD_FALSE;
end;

function TMyDevice.Init(const aObj: IInterface): IUnknown;
begin
  Result:= self as IDirect3DDevice3;
  InitVMT(aObj as IDirect3DDevice3, Result, @Obj, 42*4);
end;

function TMyDevice.NextViewport(lpDirect3DViewport: IDirect3DViewport3;
  var lplpAnotherViewport: IDirect3DViewport3; dwFlags: DWORD): HResult;
begin
  Assert(false);
  Result:= DD_FALSE;
end;

function TMyDevice.SetCurrentViewport(lpd3dViewport: IDirect3DViewport3): HResult;
begin
  Result:= Obj.SetCurrentViewport(IDirect3DViewport3(GetRaw(lpd3dViewport)));
end;

{ TMyBackBufferD3D }

procedure Blacken16(p: PChar; d: int; const r: TRect);
var
  y, w: int;
begin
  inc(p, d*r.Top + 2*r.Left);
  w:= RectW(r)*2;
  for y:= RectH(r) downto 1 do
  begin
    ZeroMemory(p, w);
    inc(p, d);
  end;
end;

function TMyBackBufferD3D.Blt(r: PRect;
  lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect; dwFlags: DWORD;
  lpDDBltFx: PDDBltFX): HResult;
var
  r1: TRect;
begin
  if (dwFlags and DDBLT_COLORFILL <> 0) and (lpDDBltFx.dwFillColor = 0) then
  begin
    r1:= Rect(0, 0, _ScreenW^, _ScreenH^);
    IntersectRect(r1, r1, r^);
    if _ScreenBuffer^ <> nil then
      Blacken16(_ScreenBuffer^, _ScreenW^*2, r1);
    Result:= DD_OK;
  end else
  begin
    ScaleRect(r);
    Result:= Surf.Blt(r, lpDDSrcSurface, lpSrcRect, dwFlags, lpDDBltFx);
  end;
end;

{ TMyFrontBufferD3D }

function TMyFrontBufferD3D.Blt(lpDestRect: PRect;
  lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect; dwFlags: DWORD;
  lpDDBltFx: PDDBltFX): HResult;
begin
  if lpDDSrcSurface = MyBackBuffer then
  begin
    ScaleRect(lpSrcRect);
    Result:= Surf.Blt(lpDestRect, BackBuffer, lpSrcRect, dwFlags, lpDDBltFx)
  end else
    Result:= Surf.Blt(lpDestRect, lpDDSrcSurface, lpSrcRect, dwFlags, lpDDBltFx);
end;

function TMyFrontBufferD3D.GetPixelFormat(out fmt: TDDPixelFormat): HResult;
begin
  MyPixelFormat(fmt, Surf.GetPixelFormat(fmt));
  Result:= DD_OK;
end;

{ TMySurface }

function TMySurfaceSW.AddAttachedSurface(
  lpDDSAttachedSurface: IDirectDrawSurface4): HResult;
begin
  Result:= Surf.AddAttachedSurface(IDirectDrawSurface4(GetRaw(lpDDSAttachedSurface)));
end;

function TMySurfaceSW.Blt(lpDestRect: PRect; lpDDSrcSurface: IDirectDrawSurface4;
  lpSrcRect: PRect; dwFlags: DWORD; lpDDBltFx: PDDBltFX): HResult;
begin
  // ignore MM6 tricks with extra surfaces when an item is carried
  if GetRaw(lpDDSrcSurface) = ptr(FrontBuffer) then
    Result:= DD_OK
  else
    Result:= Surf.Blt(lpDestRect, IDirectDrawSurface4(GetRaw(lpDDSrcSurface)),
      lpSrcRect, dwFlags, lpDDBltFx);
end;

function TMySurfaceSW.BltFast(dwX, dwY: DWORD;
  lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect;
  dwTrans: DWORD): HResult;
begin
  Result:= Surf.BltFast(dwX, dwY, IDirectDrawSurface4(GetRaw(lpDDSrcSurface)),
    lpSrcRect, dwTrans);
end;

function TMySurfaceSW.DeleteAttachedSurface(dwFlags: DWORD;
  lpDDSAttachedSurface: IDirectDrawSurface4): HResult;
begin
  Result:= Surf.DeleteAttachedSurface(dwFlags, IDirectDrawSurface4(GetRaw(lpDDSAttachedSurface)));
end;

function TMySurfaceSW.Flip(lpDDSurfaceTargetOverride: IDirectDrawSurface4;
  dwFlags: DWORD): HResult;
begin
  Result:= Surf.Flip(IDirectDrawSurface4(GetRaw(lpDDSurfaceTargetOverride)), dwFlags);
end;

function TMySurfaceSW.Lock(lpDestRect: PRect;
  out lpDDSurfaceDesc: TDDSurfaceDesc2; dwFlags: DWORD;
  hEvent: THandle): HResult;
var
  desc: TDDSurfaceDesc2;
begin
  if IsDDraw1 then
  begin
    desc.dwSize:= SizeOf(desc);
    Result:= Surf.Lock(lpDestRect, desc, dwFlags, hEvent);
    if Result <> DD_OK then  exit;
    desc.dwSize:= SizeOf(TDDSurfaceDesc);
    CopyMemory(@lpDDSurfaceDesc, @desc, desc.dwSize);
  end else
    Result:= Surf.Lock(lpDestRect, lpDDSurfaceDesc, dwFlags, hEvent);
end;

function TMySurface.Init(const Obj: IInterface): IUnknown;
begin
  Result:= self as IDirectDrawSurface4;
  InitVMT(Obj as IDirectDrawSurface4, Result, @Surf, $B4);
end;

{ TMyFrontBufferSW }

function TMyFrontBufferSW.Blt(lpDestRect: PRect;
  lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect; dwFlags: DWORD;
  lpDDBltFx: PDDBltFX): HResult;
var
  info: TDDSurfaceDesc2;
  r: TRect;
begin
  Result:= DD_OK;
  if DrawBufSW = nil then  exit;
  FillChar(info, SizeOf(info), 0);
  info.dwSize:= SizeOf(info);
  Result:= BackBuffer.Lock(nil, info, DDLOCK_NOSYSLOCK or DDLOCK_WAIT, 0);
  if Result <> DD_OK then  exit;
  DXProxyDraw(ptr(DrawBufSW), @info);
  BackBuffer.Unlock(nil);
  if lpDDSrcSurface <> MyBackBuffer then
    _NeedRedraw^:= 1;
  r:= Rect(0, 0, RenderW, RenderH);
  Result:= inherited Blt(lpDestRect, MyBackBuffer, @r, dwFlags, lpDDBltFx);
end;

function TMyFrontBufferSW.GetPixelFormat(out fmt: TDDPixelFormat): HResult;
begin
  MyPixelFormat(fmt, Surf.GetPixelFormat(fmt));
  Result:= DD_OK;
end;

{ TMyBackBufferSW }

function TMyBackBufferSW.Blt(lpDestRect: PRect;
  lpDDSrcSurface: IDirectDrawSurface4; lpSrcRect: PRect; dwFlags: DWORD;
  lpDDBltFx: PDDBltFX): HResult;
begin
  if (lpDDSrcSurface = nil) and (DrawBufSW <> nil) then
    FillChar(DrawBufSW[0], length(DrawBufSW)*2, 0);
  Result:= DD_OK;
end;

function TMyBackBufferSW.Lock(lpDestRect: PRect;
  out lpDDSurfaceDesc: TDDSurfaceDesc2; dwFlags: DWORD;
  hEvent: THandle): HResult;
var
  SW, SH: int;
begin
  SW:= max(_ScreenW^, 640);
  SH:= max(_ScreenH^, 480);
  SetLength(DrawBufSW, SW*SH);
  with lpDDSurfaceDesc do
  begin
    dwWidth:= SW;
    dwHeight:= SH;
    lPitch:= SW*2;
    lpSurface:= ptr(DrawBufSW);
    with ddpfPixelFormat do
    begin
      dwRGBBitCount:= 16;
      dwRBitMask:= $F800;
      dwGBitMask:= $7E0;
      dwBBitMask:= $1F;
      dwRGBAlphaBitMask:= 0;
    end;
  end;
  Result:= DD_OK;
end;

function TMyBackBufferSW.Unlock(lpRect: PRect): HResult;
begin
  Result:= DD_OK;
end;

end.
