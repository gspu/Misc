unit Common;

interface

uses
  Windows, Messages, SysUtils, Classes, IniFiles, RSSysUtils, RSQ, Math;

type
  TSaveSlotFile = array[0..279] of char;
  TSaveSlotFiles = array[0..39] of TSaveSlotFile;
  PSaveSlotFiles = ^TSaveSlotFiles;
  PPSaveSlotFiles = ^PSaveSlotFiles;

const
  _Paused = pint($50BA64);
  _UsingBook = pint($6E202C);
  _CurrentMember = pint($507A6C);
  _CurrentScreen = pint($4E28D8);
  _MainMenuCode = pint($6A0BC4);
  _CurrentCharScreen = pint($506DC8);
  _NeedRedraw = pint($576EAC);
  _TextGameSaved = ppchar($5E4A40);
  _TextBuffer1 = pchar($5C5C30);
  _TextBuffer2 = pchar($5C6400);
  _ItemInMouse = pint($AD458C);
  _PartyMembers = $A74F44;
  _Party_State = $AD45B0;
  _Party_X = pint($ACD4EC);
  _Party_Y = pint($ACD4F0);
  _Party_Z = pint($ACD4F4);
  _Party_Direction = pint($ACD4F8);
  _Party_Angle = pint($ACD4FC);
  __Party_Height = $ACCE3C;
  _Party_Height = pint(__Party_Height);
  _Party_EyeLevel = pint($ACCE44);
  _TurnBased = pbool($ACD6B4);
  _TurnBasedPhase = pint($4F86DC);
  _TurnBasedObjectsInAir = $4F86F4;
  _TurnBasedDelays = $AE2F7C;
  _AutosaveFile = PPChar($5E4994);
  _AutosaveName = PPChar($5E4040);
  _SaveScroll = pint($6A0B1C);
  _SaveSlot = pint($6A0B20);
  _SaveSlotsFiles = PPSaveSlotFiles($45EB63);
  _SaveSlotsFilesLim = PPChar($45EC35);
  _SaveSlotsCount = pint($69CDA4);
  __PSaveSlotsHeaders = $45F661;
  __ItemsTxt = $41D8E1;
  _ItemsTxt = pint(__ItemsTxt);
  _MainWindow = puint($6BE174);
  _ScreenW = pint($E31B68);
  _ScreenH = pint($E31B64);
  _ScreenBuffer = pptr($E31B54);
  _TimeDelta = pint($50BA7C);
  _Flying = pint($ACD53C);
  _IsD3D = pbool($DF1A68);
  _startinwindow = pbool($DF1A6C);
  _PlayersArray = $ACD804;
  __Windowed = $E31AC0;
  _Windowed = pbool(__Windowed);
  _GreenColorBits = pint($E31B38);
  _RedMask = pint($E31B40);
  _GreenMask = pint($E31B44);
  _BlueMask = pint($E31B48);
  _MapName = $6BE1C4;
  _MapStats = $5CAA38;
  _RightButtonPressed = pbool($507A70);
  _WindowedGWLStyle = pint($6BE1B8);
  _IndoorOrOutdoor = pint($6BE1E0);
  _AbortMovie = pbool($F8B9F4);
  _ViewMulOutdoor = pint($6BDF04);
  _ViewMulIndoorSW = psingle($507B7C);
  _RenderRect = PRect($F8BAA4);
  __SpritesToDrawCount = $518660;
  _SpritesToDrawCount = pint(__SpritesToDrawCount);
  _CGame = PPChar($71FE94);
  _IsLoadingBig = pbool($576CB0 + $3C);
  _IsLoadingSmall = pbool($576CB0 + $158);
  _UITextColor = pint($50797C);
  _UITextShadowColor = pint($507978);
  _ArcomageActive = PBoolean($505812);
  _ChestDlg = pptr($507A38);
  _NoHint = PChar($5063F0);
  _ShowRingsHint = PPChar($5E4100);

  _PauseTime: procedure(a1: int = 0; a2: int = 0; this: int = $50BA60) = ptr($4262F2);
  _ReleaseMouse: TProcedure = ptr($4356EE); 
  _SaveGameToSlot: procedure(n1,n2, slot:int) = ptr($4600B1);
  _DoSaveGame: procedure(n1,unk, autosave: int) = ptr($45F4A2); 
  _DoLoadGame: procedure(n1,n2, slot: int) = ptr($45EEC3);
  _FindActiveMember: function(n1: int = 0; n2: int = 0; this: int = $ACCE38):int = ptr($493707);
  _ShowStatusText: procedure(a0, seconds: int; text: PChar) = ptr($44C1A1);
  _OpenInventory_part: function(a1: int = 0; a2: int = 0; screen: int = 7):int = ptr($4215CF);
  _OpenInventory_result = pint($507A4C);
  _LoadPaperDollGraphics: TProcedure = ptr($43BCCA);
  _IsScreenWithCustomRightSide: function: Bool = ptr($441030); 
  _access: function(fileName: PChar; unk: int = 0): int cdecl = ptr($4D6CD6);
  _Alloc: function(n1,n2: int; allocator: ptr; name: PChar; size, unk: int):ptr = ptr($4266FE);
  _Allocator = ptr($7029A8);
  _LoadMapTrack: procedure = ptr($4ABF53);
  _PlaySound = $4AA29B;
  _PlaySoundStruct = $F78F58;
  _LoadSprite: function(n1, n2, this: int; pal: int; name: PChar):int = ptr($4AC723);
  _strcmpi: function(const s1, s2: PChar): int cdecl = ptr($4CAAF0);
  _MapStats_Find: function(n1, n2, this: int; name: PChar): int = ptr($4547CF);
  _IsScreenOpaque: function: BOOL = ptr($42266B);
  _IsMoviePlaying: function: Boolean = ptr($4BF35F);
  _ShowMovie: procedure(_, y: int; name: PChar; DoubleSize: LongBool; ExitScreen: int = 1) = ptr($4BE671);
  _ShowStdMovie: procedure(id: int; ResumeMouse: LongBool) stdcall = ptr($4A94BD);
  _ExitMovie: procedure(_1: int = 0; _2: int = 0; _3: int = $F8B988) = ptr($4BEB3A);
  _StopSounds: procedure(_: int = 0; __: int = 0; this: int = $F78F58; a1: int = -1; a2: int = -1) = ptr($4AB69F);
  _AddButton: function(dlg: ptr; x, y, w, h, shape, cmdX, action, acionInfo, key: int; hint: PChar; SpritesVarArg: ptr): ptr cdecl varargs = ptr($41D0D8);
  _DeleteButton: procedure(_,__: int; btn: ptr) = ptr($41D081);

  _CommandsArray = $721458;
  _AddCommand: procedure(a1, a2, this, cmd: int) = ptr($4760C5);

  _LodFind: function(_,__, Lod, NoSort: int; Name: PChar): ptr = ptr($4615BD);
  _fread: function(var Buf; Size, Count: int; f: ptr): int cdecl = ptr($4CB8A5);
  _fseek: function(f: ptr; Offset, Origin: int): int cdecl = ptr($4CB7EC);
  _Deflate: procedure(n1: int; UnpSize: pint; var UnpBuf; PkSize: int; var Pk) = ptr($4C2F60);
  _LoadPalette: function(n1, n2, Palettes, PalId: int): int = ptr($48A3A2);
  _RGBtoHSV: procedure(_: int; var S, H, V: Single; B, G, R: Single) = ptr($48A790);
  _HSVtoRGB: procedure(_: int; var G, R: Single; V, S, H: Single; var B: Single) = ptr($48A629);
  _LoadLodBitmap: function(_,__, lod: int; palKind: int; name: PChar): int = ptr($40FB2C);
  _DoLoadLodBitmap: function(_,__, lod: int; palKind: int; name: PChar; var bmp): int = ptr($40FC14);
  _LoadBitmapInPlace: function(_,__, lod: int; palKind: int; name: PChar; var bmp): int = ptr($41052E);
  _FreeBitmap: procedure(_,_1: int; var bmp) = ptr($40F788);
  _BitmapsLod = $6F0D00;
  _IconsLod = $6D0490;

  _Chest_CanPlaceItem: function(n1, itemType, pos, chest: int): BOOL = ptr($41FE1A);
  _Chest_PlaceItem: procedure(n1, itemIndex, pos, chest: int) = ptr($4200E7);

  _Character_GetWeaponDelay: function(n1, n2: int; this:ptr; ranged: LongBool):int = ptr($48E19B);
  _Character_IsAlive: function(a1,a2, member:ptr):Bool = ptr($492C03);
  _Character_WearsItem: function(_,__, pl, slot, item: int): LongBool = ptr($48D6EF);
  _Character_WearsItemWithEnchantSpec: function(n1,n2:int; this:ptr; slot, id:int):BOOL = ptr($48D6B6);
  _Character_SetDelay: procedure(n1, n2: int; this: ptr; delay: int) = ptr($48E962);
  _TurnBased_CharacterActed: procedure(n1: int = 0; n2: int = 0; this: int = $4F86D8) = ptr($40471C);

  _Mon_IsAgainstMon: function(_, defender, attacker: ptr): int = ptr($40104C);
  _IsMonsterOfKind: function(_, kind: int; mon: ptr): BOOL = ptr($438BCE); 

  _MonOff_vx = $94;
  _MonOff_vy = $96;
  _MonOff_Size = $344;

  _SpritesLod = $6E2048;
  _SpritesOld = _SpritesLod + $23C;
  SpritesMax = 10000;
  _SpritesLodCount = pint(_SpritesLod + $EC9C);

function GameCursorPos:PPoint;
  
const
  SWrong: string = 'This is not a valid mm7.exe file. Check failed at address %X';
  SCaption: string = 'GrayFace MM7 Patch';
  SIni = 'mm7.ini';
  SIni2 = 'mm7lang.ini';
  DummyFalse: Bool = false;

implementation

function GameCursorPos:PPoint;
begin
  Result:= PPoint(PPChar($720808)^ + $108);
end;

end.
