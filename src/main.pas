unit main;

interface

uses
  Windows, Classes, Graphics, Forms, SysUtils, ExtCtrls, Controls, StdCtrls, Dialogs, Math,
  Menus, Contnrs, utils, cons;

type
  TMainForm = class(TForm)
    GameTimer: TTimer;
    procedure FormCreate(Sender: TObject);
    procedure FormPaint(Sender: TObject);
    procedure FormKeyDown(Sender: TObject; var Key: Word;
      Shift: TShiftState);
    procedure ProcessMsg;
    procedure EndGame;
    procedure FormCloseQuery(Sender: TObject; var CanClose: Boolean);
    procedure FormResize(Sender: TObject);
    procedure InitGame;
    procedure GameTimerTimer(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure AnimFly(x1,y1,x2,y2:integer;symbol:string; color:byte);
    procedure FormActivate(Sender: TObject);
    procedure Cls;
    procedure Redraw;
    procedure SetFont(newFont: string);
    procedure SetBgColor(c: LongInt);
    procedure DrawHPBar(x,y: byte; color: LongInt; hp, rhp: word); //��������� ����� ��� ���������
    procedure DrawBar(x,y,l: word; c1,c2: LONGWORD); //����������� �����
    procedure ShowCursor;
    procedure HideCursor;
  public
    procedure DrawString(x,y: byte; c: LongInt; s: string; l: byte = WindowX); overload;
    procedure DrawString(x,y: byte; c: LongInt; bs: TBrushStyle; s: string; l: byte = WindowX); overload;
  private
    procedure CMDialogKey( Var msg: TCMDialogKey );
    message CM_DIALOGKEY;
  public
  end;

var
  MainForm             : TMainForm;
  KeyQueue             : TIntQueue;            //����� ������� ������
  _Screen,GrayScreen    : TBitMap;              // �������� ��� �������-������������
  GameMenu,                                    // ������� ����
  AskForQuit,                                  // ������������� ������
  Inputing, Debug      : boolean;              // ����� �����
  GameState,                                   // ��������� ����
  MenuSelected2,                               // ��������� ������� � ����
  VidFilter,                                   // �������� ������ ���� ���������� � ��������� (0-���)
  wtd,                                         // ��� ������� ��� ������ �������
  LastGameState,                               // ��������� ��������� ����
  WasEqOrInv,                                  // ���� ������� ���������� ��� ���������
  PlayMode             : byte;                 // ��������� ����� ����
  GameVersion          : string;               // ������ ����
  Answer               : string[1];            // ��������� �����
  MenuSelected,
  a                    : integer;
  DC                   : HDC;                  // �������� ����������

implementation

{$R *.dfm}

uses
  Msg, Player, Map, Tile, Help, Items, Ability, MapEditor, Liquid,
  Conf, SUtils, Script, MBox, Vars, Monsters, wlog;

{ ������������� }
procedure TMainForm.FormCreate(Sender: TObject);
begin
  if Debug then
  begin
    Caption := '[Debug] '+Caption;
    Run('CreatePC.pas', true);
    Run('GenDungeon.pas', true);
    Run('GenName.pas', true);
    Run('InitStory.pas', true);
    Run('NPCTalk.pas', true);
  end;
  // �������� ������� �����
  DC := GetDC(MainForm.Handle);
  // ������ ������� ����
  Menu := nil;
  // ������ ����
  ClientWidth := WindowX * CharX;
  ClientHeight := WindowY * CharY;
  with _Screen do
  begin
    Width := ClientWidth;
    Height := ClientHeight;
  end;
  with GrayScreen do
  begin
    Width := ClientWidth;
    Height := ClientHeight;
  end;
  SetFont(FontMsg);
  GameTimer.Enabled := False;
  MenuSelected := 1;
  // ������� ����
  KeyQueue := TIntQueue.Create;
  ChangeGameState(gsINTRO);
end;

{ ��������� }
procedure TMainForm.FormPaint(Sender: TObject);
var OldStyle : TBrushStyle;
begin
  // ��������� �������� ������ ������
  if GameState in [gsPLAY, gsCLOSE, gsLOOK, gsCHOOSEMONSTER, gsOPEN, gsAIM, gsCONSOLE,
                   gsEQUIPMENT, gsINVENTORY, gsUSEMENU] then
  begin
    if not((GameState = gsPLAY)and GameMenu) then Cls;
  end;
  // �������
  case GameState of
    gsPLAY, gsCLOSE, gsLOOK, gsCHOOSEMONSTER, gsOPEN, gsAIM, gsCONSOLE:
    if not((GameState = gsPLAY)and GameMenu) then
    begin
      // ������� �����
      M.DrawScene;
      // ������� ���������� � �����
      pc.WriteInfo;      
      if pc.Hp <= 0 then BlackWhite(_Screen);
      // ������� ���������
      if GameState = gsConsole then ShowLog else ShowMsgs;
    end;
    gsEQUIPMENT    : pc.Equipment;
    gsINVENTORY    : pc.Inventory;
    gsUSEMENU      : begin if LastGameState = gsEQUIPMENT then pc.Equipment else pc.Inventory; pc.UseMenu; end;
  end;
//���������� ������
  if GameTimer.Enabled then
  begin
    BitBlt(_Screen.Canvas.Handle, 0, 0, Screen.Width, Screen.Height, GrayScreen.Canvas.Handle, 0, 0, SRCCopy);
    With _Screen.Canvas do
    begin
      Brush.Color := 0;
      Font.Color := MyRGB(160,160,160);
      Textout(InputX*CharX, InputY*CharY, InputString);
      if GetTickCount mod 1000 < 500 then
      begin
        OldStyle := Brush.Style;
        Brush.Style := bsClear;
        Font.Color := cLIGHTGREEN;
        Textout((InputX+(InputPos))*CharX, InputY*CharY, '_');
        Brush.Style := OldStyle;
      end;
    end;
  end;
  SetStretchBltMode(_Screen.Canvas.Handle, STRETCH_DELETESCANS);
  StretchBlt(DC, 0, 0, MainForm.ClientRect.Right, MainForm.ClientRect.Bottom,
  _Screen.Canvas.Handle, 0, 0, _Screen.Width, _Screen.Height, SRCCopy);
end;

{ ������� �� ������� }
procedure TMainForm.FormKeyDown(Sender: TObject; var Key: Word;
  Shift: TShiftState);
var
  i : integer;
  n,s : string;
  Item : TItem;
  b: boolean;
begin
  // ���� ������ �� Shift, Alt ��� Ctrl � ������ �� ��������� �����
  if Key <> 16 then
  begin
  // ��������
  if Key = 116 then TakeScreenShot else
    if (Inputing) then
      KeyQueue.Push(Key)
    else
      // ��� ���������
      begin
        ClearMsg;
        pc.turn := 0;
        case GameState of
          // �� ����� ����
          gsPLAY:
          begin
            { ������������ �� ��������� alt+��� �������}
            if ssAlt in Shift then
            begin
              If ((GetKeyState(VK_LEFT) AND 128)=128) and ((GetKeyState(VK_DOWN) AND 128)=128) then
                pc.Move(-1,1) else
              If ((GetKeyState(VK_RIGHT) AND 128)=128) and ((GetKeyState(VK_DOWN) AND 128)=128) then
                pc.Move(1,1) else
              If ((GetKeyState(VK_LEFT) AND 128)=128) and ((GetKeyState(VK_UP) AND 128)=128) then
                pc.Move(-1,-1) else
              If ((GetKeyState(VK_RIGHT) AND 128)=128) and ((GetKeyState(VK_UP) AND 128)=128) then
                pc.Move(1,-1);
            end else
            case Key of
              { ������������ }
              35,97,49     : if ssShift in Shift then pc.Run(-1,1) else pc.Move(-1,1);
              40,98,50     : if ssShift in Shift then pc.Run(0,1) else pc.Move(0,1);
              34,99,51     : if ssShift in Shift then pc.Run(1,1) else pc.Move(1,1);
              37,100,52    : if ssShift in Shift then pc.Run(-1,0) else pc.Move(-1,0);
              12,101,53,32 : pc.Move(0,0);
              39,102,54    : if ssShift in Shift then pc.Run(1,0) else pc.Move(1,0);
              36,103,55    : if ssShift in Shift then pc.Run(-1,-1) else pc.Move(-1,-1);
              38,104,56    : if ssShift in Shift then pc.Run(0,-1) else pc.Move(0,-1);
              33,105,57    : if ssShift in Shift then pc.Run(1,-1) else pc.Move(1,-1);
              13           : pc.UseStairs;
              { �������� }
              // ���� 'Esc'
              27        :
              begin
                {MenuSelected := 1;
                GameMenu := TRUE;}
                StartGameMenu;
              end;
              // ������� ����� 'c'
              67        : pc.SearchForDoors;
              // �������� 'l'
              76        :
              begin
                ChangeGameState(gsLOOK);
                lx := pc.x;
                ly := pc.y;
                pc.AnalysePlace(lx,ly,2);
              end;
              // �������� 't'
              84        : pc.SearchForAlive(2);
              // ������ ������� 'q'
              81        :
                pc.QuestList;
              // ������ 'f'
              70        :
              begin
                if pc.HaveItemVid(14) then
                begin
                  MenuSelected := 1;
                  VidFilter := 14;
                  ChangeGameState(gsINVENTORY);
                end else
                  AddMsg('� ���� ��� ������ ���������!',0);
              end;
              // ������ 'd'
              68        :
              begin
                if pc.HaveItemVid(19) then
                begin
                  MenuSelected := 1;
                  VidFilter := 19;
                  ChangeGameState(gsINVENTORY);
                end else
                  AddMsg('� ��������� ��� ������, ��� ����� ������!',0);
              end;
              // ���������� 'e'
              69        :
              begin
                  MenuSelected := 1;
                  WasEqOrInv := 2;
                  ChangeGameState(gsEQUIPMENT);
              end;
              // ��������� 'i'
              73        :
              begin
                if pc.ItemsAmount > 0 then
                begin
                  MenuSelected := 1;
                  VidFilter := 0;
                  WasEqOrInv := 1;
                  ChangeGameState(gsINVENTORY);
                end else
                  AddMsg('���� ��������� ����!',0);
              end;
              // ������ '?'
              112       :
                          ShowHelp;
              // ��������� 'a'
              65        : pc.SearchForAlive(1);
              // ������� 'g'
              71        :
              begin
                i := 1;
                if M.Item[pc.x,pc.y].amount > 1 then
                begin
                  // ���� ������, �� ����� ��� ��� ��������
                  if not (ssShift in Shift) then
                    i := M.Item[pc.x,pc.y].amount else
                      begin
                        AddMsg(ItemName(M.Item[pc.x,pc.y], 0, TRUE)+'. ������� ������ �����?',0);
                        n := Input(LastMsgL+1, MapY+(LastMsgY-1), IntToStr(M.Item[pc.x,pc.y].amount));
                        if TryStrToInt(n,i) then
                        begin
                          if (i > M.Item[pc.x,pc.y].amount) then
                          begin
                            AddMsg('������� ������� ������� ��������.',0);
                            i := 0;
                          end;
                        end else
                          begin
                            AddMsg('����� ������ �����.',0);
                            i := 0;
                          end;
                      end;
                end;
                if i > 0 then
                begin
                  case pc.PickUp(M.Item[pc.x,pc.y], FALSE,i) of
                    0 :
                    begin
                      Item := M.Item[pc.x,pc.y];
                      Item.amount := i;
                      AddMsg('�� ���������� '+ItemName(Item,0,TRUE)+'.',0);
                      if M.Item[pc.x,pc.y].amount > i then
                        dec(M.Item[pc.x,pc.y].amount,i) else
                          M.Item[pc.x,pc.y].id := 0;
                    end;
                    1 : AddMsg('����� ������ �� �����!',0);
                    2 : AddMsg('���� ��������� ��������� �����! ��� ����� ����� ���������?! ���� �� �������� � ���, ����� �������� ��� ������� ��������� ����...',0);
                    3 : AddMsg('�� �� ������ ����� ������... ������� ������!',0);
                  end;
                end;
              end;
              // ������� 'o'
              79        :
              begin
                AddMsg('��� �� ������ �������?',0);
                ChangeGameState(gsOPEN);
              end;
              // ����� � ���� ������ � ����������� 'x'
              88        :
                SkillsAndAbilitys;
              // ������� ��������� 'm'
              77        :
                ShowHistory;
              // �������� 'y'
              89        :
              begin
                AddMsg('��� �� ������ ��������?',0);
                Input(LastMsgL+1, MapY+(LastMsgY-1), '');
              end;
              //������� '~'
              192 :
              if Debug then
              begin
                changeGameState(gsConsole);
                repeat
                  ShowLog;
                  s := Input(2, MapY, '',b);
                  if s <> '' then
                  begin
                    Log(' > '+s);
                    Run(s+';');
                  end;
                until (s = '');
                changeGameState(gsPlay);
              end;
              // �������� 's'
              83       :  pc.PrepareShooting(pc.eq[7], pc.eq[13], 1);
              // �������� ������� 'tab'
              VK_TAB    :
              begin
                case pc.tactic of
                   0 : AddMsg('������� ������� - $�����������$.',0);
                   1 : AddMsg('������� ������� - *����������� ���������*.',0);
                   2 : AddMsg('������� ������� - #������#.',0);
                end;
                case Ask('������� �������: (#A#) - ����������� ���������, (#S#) - �����������, (#D#) - ����������.') of
                  'A' :
                  begin
                    ClearMsg;
                    pc.tactic := 1;
                    AddMsg('������� ����������� ���������.',0);
                    AddMsg('������������� ������:',0);
                    AddMsg('#+50% � ��������� ��������� � �����#, *-50% � ��������� � ������������� �����*.',0);
                  end;
                  'S' :
                  begin
                    ClearMsg;
                    pc.tactic := 0;
                    AddMsg('������� ����������� �������.',0);
                    AddMsg('������� ������ � ������� �� ����� ���.',0);
                  end;
                  'D' :
                  begin
                    ClearMsg;
                    pc.tactic := 2;
                    AddMsg('������� �������� �������.',0);
                    AddMsg('������������� ������:',0);
                    AddMsg('*-50% � ��������� ��������� � �����*, #+50% � ��������� � ������������� �����#.',0);
                  end;
                  ELSE
                    AddMsg('�� �����{/a} �� ������ �������.',0);
                end;
              end;
            end;
          end;
          // ������� �����
          gsCLOSE:
          begin
            case Key of
              35,97,49  : pc.CloseDoor(-1,1);
              40,98,50  : pc.CloseDoor(0,1);
              34,99,51  : pc.CloseDoor(1,1);
              37,100,52 : pc.CloseDoor(-1,0);
              39,102,54 : pc.CloseDoor(1,0);
              36,103,55 : pc.CloseDoor(-1,-1);
              38,104,56 : pc.CloseDoor(0,-1);
              33,105,57 : pc.CloseDoor(1,-1);
              else
                AddDrawMsg('������� ������������ �����������!',0);
            end;
            pc.turn := 1;
            ChangeGameState(gsPLAY);
          end;
          // �������
          gsOPEN:
          begin
            case Key of
              35,97,49  : pc.Open(-1,1);
              40,98,50  : pc.Open(0,1);
              34,99,51  : pc.Open(1,1);
              37,100,52 : pc.Open(-1,0);
              39,102,54 : pc.Open(1,0);
              36,103,55 : pc.Open(-1,-1);
              38,104,56 : pc.Open(0,-1);
              33,105,57 : pc.Open(1,-1);
              else
                AddDrawMsg('������� ������������ �����������!',0);
            end;
            pc.turn := 1;
            ChangeGameState(gsPLAY);
          end;
          // ���������!
          gsCHOOSEMONSTER:
          begin
            case Key of
              35,97,49  :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x-1,pc.y+1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x-1,pc.y+1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x-1,pc.y+1]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x-1,pc.y+1]]);
              end;
              40,98,50  :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x,pc.y+1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x,pc.y+1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x,pc.y+1]]) else
                       pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x,pc.y+1]]);
              end;
              34,99,51  :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x+1,pc.y+1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x+1,pc.y+1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x+1,pc.y+1]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x+1,pc.y+1]]);
              end;
              37,100,52 :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x-1,pc.y]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x-1,pc.y]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x-1,pc.y]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x-1,pc.y]]);
              end;
              39,102,54 :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x+1,pc.y]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x+1,pc.y]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x+1,pc.y]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x+1,pc.y]]);
              end;
              36,103,55 :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x-1,pc.y-1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x-1,pc.y-1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x-1,pc.y-1]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x-1,pc.y-1]]);
              end;
              38,104,56 :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x,pc.y-1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x,pc.y-1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x,pc.y-1]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x,pc.y-1]]);
              end;
              33,105,57 :
              case wtd of
                1 : pc.Fight(M.MonL[M.MonP[pc.x+1,pc.y-1]], 0);
                2 : pc.Talk(M.MonL[M.MonP[pc.x+1,pc.y-1]]);
                3 : if LastGameState = gsEQUIPMENT then pc.GiveItem(MenuSelected, 2, M.MonL[M.MonP[pc.x+1,pc.y-1]]) else
                      pc.GiveItem(MenuSelected, 1, M.MonL[M.MonP[pc.x+1,pc.y-1]]);
              end;
              else
                AddDrawMsg('������� ������������ �����������!',0);
            end;
            pc.turn := 1;
            ChangeGameState(gsPLAY);
          end;
          // ���������� �������� �������
          gsLOOK:
          begin
            case Key of
              35,97,49  : pc.MoveLook(-1,1);
              40,98,50  : pc.MoveLook(0,1);
              34,99,51  : pc.MoveLook(1,1);
              37,100,52 : pc.MoveLook(-1,0);
              12,101,53 : pc.MoveLook(0,0);
              39,102,54 : pc.MoveLook(1,0);
              36,103,55 : pc.MoveLook(-1,-1);
              38,104,56 : pc.MoveLook(0,-1);
              33,105,57 : pc.MoveLook(1,-1);
              13        : AnimFly(pc.x,pc.y,lx,ly,'`',crBrown);
              else
                ChangeGameState(gsPlay);
              M.DrawScene;
            end;
          end;
          // ���������� �������� �������
          gsAIM:
          begin
            case Key of
              35,97,49  : pc.MoveAim(-1,1);
              40,98,50  : pc.MoveAim(0,1);
              34,99,51  : pc.MoveAim(1,1);
              37,100,52 : pc.MoveAim(-1,0);
              12,101,53 : pc.MoveAim(0,0);
              39,102,54 : pc.MoveAim(1,0);
              36,103,55 : pc.MoveAim(-1,-1);
              38,104,56 : pc.MoveAim(0,-1);
              33,105,57 : pc.MoveAim(1,-1);
              13,83     :
                if (lx = pc.x) and (ly = pc.y) then
                  AddMsg('����� ����� ESC, ���� �� ��� ������ �������!',0) else
                  begin
                    // ������� ��������� �������
                    if Bow.id = 0 then
                      pc.DeleteItemInv(13, 1, 2) else
                      begin
                        case WasEqOrInv of
                          1 : pc.DeleteItemInv(MenuSelected, 1, 1);
                          2 : pc.DeleteItemInv(MenuSelected, 1, 2);
                        end;
                      end;
                    ChangeGameState(gsPLAY);
                    pc.StartShooting(ShootingMode);
                    pc.turn := 1;
                  end;
              ELSE
                ChangeGameState(gsPLAY);
              M.DrawScene;
            end;
          end;
          // ������ �������, ����������, ������
          gsEQUIPMENT, gsINVENTORY, gsUSEMENU:
          begin
            // ����� � ���� ��� � ������ �����
            if GameState = gsUSEMENU then
            begin
              if Key = 27 then
                ChangeGameState(LastGameState);
            end else
              if (Key = 27) or (Key = 32) then ChangeGameState(gsPLAY);

            // ���������� � ����������
            if GameState = gsEQUIPMENT then
            begin
              case Key of
                //i
                73 :
                if pc.ItemsAmount > 0 then
                begin
                  MenuSelected := 1;
                  VidFilter := 0;
                  pc.Inventory;
                  ChangeGameState(gsINVENTORY);
                end;
                // �����
                38,104,56 :
                  if MenuSelected = 1 then MenuSelected := EqAmount else dec(MenuSelected);
                // ����
                40,98,50 :
                  if MenuSelected = EqAmount then MenuSelected := 1 else inc(MenuSelected);
                // ����� / ����� � ���������
                13 :
                begin
                  // �����
                  if pc.eq[MenuSelected].id > 0 then
                  begin
                    MenuSelected2 := 1;
                    pc.UseMenu;
                    ChangeGameState(gsUSEMENU);
                  end else
                    if pc.HaveItemVid(Eq2Vid(MenuSelected)) then
                    begin
                      VidFilter := Eq2Vid(MenuSelected);
                      MenuSelected := 1;
                      ChangeGameState(gsINVENTORY);
                    end;
                end;
              end;
            end ELSE

            // ���������� � ���������
            if GameState = gsINVENTORY then
            begin
              case Key of
                //i
                73 :
                begin
                  MenuSelected := 1;
                  pc.Equipment;
                  ChangeGameState(gsEQUIPMENT);
                end;
                // �����
                38,104,56 :
                  if VidFilter = 0 then
                  begin
                    if MenuSelected = 1 then MenuSelected := ReturnInvAmount else dec(MenuSelected);
                  end else
                    if MenuSelected = 1 then MenuSelected := ReturnInvListAmount else dec(MenuSelected);
                // ����
                40,98,50 :
                  if VidFilter = 0 then
                  begin
                    if MenuSelected = ReturnInvAmount then MenuSelected := 1 else inc(MenuSelected);
                  end else
                    if MenuSelected = ReturnInvListAmount then MenuSelected := 1 else inc(MenuSelected);
                // ������� ������ �������� � ���������
                13 :
                begin
                  if VidFilter = 0 then
                  begin
                    MenuSelected2 := 1;
                    pc.UseMenu;
                    ChangeGameState(gsUSEMENU);
                  end else
                    UseItem(InvList[MenuSelected]);
                end;
              end;
            end ELSE

          // ������ �������� ��� ���������
          if GameState = gsUSEMENU then
          begin
            case Key of
              // �����
              38,104,56 :
              begin
                if MenuSelected2 = 1 then MenuSelected2 := HOWMANYVARIANTS else dec(MenuSelected2);
                Redraw;
              end;
              // ����
              40,98,50 :
              begin
                if MenuSelected2 = HOWMANYVARIANTS then MenuSelected2 := 1 else inc(MenuSelected2);
                Redraw;
              end;
              // ������� ��������� �������� � ���������
              13 :
              begin
                case MenuSelected2 of
                  1: // ������������
                  begin
                    //� ����������
                    if LastGameState = gsEQUIPMENT then
                    begin
                      case pc.PickUp(pc.eq[MenuSelected], TRUE, pc.eq[MenuSelected].amount) of
                        0 :
                        begin
                          ItemOnOff(pc.eq[MenuSelected], FALSE);
                          AddMsg('�� �������{/a} '+ItemName(pc.eq[MenuSelected], 1, TRUE)+' ������� � ���������.',0);
                          pc.eq[MenuSelected].id := 0;
                          ChangeGameState(gsEQUIPMENT);
                        end;
                        1 :
                        begin
                          AddMsg('*�� �������{/a} ������� ������� � ���� ��������� :)*',0);
                          ChangeGameState(gsPLAY);
                        end;
                        2 :
                        begin
                          AddMsg('���� ��������� ��������� �����! ��� ��� ���� �������� ����� ��� � �����.',0);
                          ChangeGameState(gsPLAY);
                        end;
                        3 :
                        begin
                          AddMsg('*����� ���� �� ������ - ���� ���� � ���� ����������, �� ������ �������� ��, ��� �� ��� ������ � ���������.*',0);
                          ChangeGameState(gsPLAY);
                        end;
                      end;
                    end else
                      UseItem(MenuSelected);
                  end;
                  2: // �����������
                  begin
                    if LastGameState = gsEQUIPMENT then
                      ExamineItem(pc.Eq[MenuSelected]) else
                        ExamineItem(pc.Inv[MenuSelected]);
                    ChangeGameState(gsPLAY);
                    pc.turn := 1;
                  end;
                  3: // �������
                  begin
                    if LastGameState = gsEQUIPMENT then
                      pc.PrepareShooting(pc.Eq[MenuSelected], pc.Eq[MenuSelected], 2) else
                        pc.PrepareShooting(pc.Inv[MenuSelected], pc.Inv[MenuSelected], 2);
                  end;
                  4: // ������
                  begin
                    GameState :=gsPLAY;
                    pc.SearchForAlive(3);
                  end;
                  5: // ��������
                  begin
                    ChangeGameState(gsPLAY);
                    if LastGameState = gsEQUIPMENT then
                    begin
                      i := 1;
                      if pc.Eq[MenuSelected].amount > 1 then
                      begin
                        AddMsg(ItemName(pc.Eq[MenuSelected], 0, TRUE)+'. ������� ������ ��������?',0);
                        n := Input(LastMsgL+1, MapY+(LastMsgY-1), IntToStr(pc.Eq[MenuSelected].amount));
                        if TryStrToInt(n,i) then
                        begin
                          if (i > pc.Eq[MenuSelected].amount) then
                          begin
                            AddMsg('������� ������� ������� ��������.',0);
                            i := 0;
                          end;
                        end else
                          begin
                            AddMsg('����� ������ �����.',0);
                            i := 0;
                          end;
                      end;
                      if i > 0 then
                      begin
                        if PutItem(pc.x,pc.y, pc.Eq[MenuSelected], i) then
                        begin
                          Item := pc.Eq[MenuSelected];
                          Item.amount := i;
                          AddMsg('�� ����������� '+ItemName(Item,0,TRUE)+'.',0);
                          pc.DeleteItemInv(MenuSelected, i, 2);
                          pc.turn := 1;
                        end else
                          AddMsg('����� ��� ����� ��� ����, ��� �� �������� ���-����!',0);
                      end;
                    end else
                      begin
                        i := 1;
                        if pc.Inv[MenuSelected].amount > 1 then
                        begin
                          AddMsg(ItemName(pc.Inv[MenuSelected], 0, TRUE)+'. ������� ������ ��������?',0);
                          n := Input(LastMsgL+1, MapY+(LastMsgY-1), IntToStr(pc.Inv[MenuSelected].amount));
                          if TryStrToInt(n,i) then
                          begin
                            if (i > pc.Inv[MenuSelected].amount) then
                            begin
                              AddMsg('������� ������� ������� ��������.',0);
                              i := 0;
                            end;
                          end else
                            begin
                              AddMsg('����� ������ �����.',0);
                              i := 0;
                            end;
                        end;
                        if i > 0 then
                        begin
                          if PutItem(pc.x,pc.y, pc.Inv[MenuSelected], i) then
                          begin
                            Item := pc.Inv[MenuSelected];
                            Item.amount := i;
                            AddMsg('�� ����������� '+ItemName(Item,0,TRUE)+'.',0);
                            pc.DeleteItemInv(MenuSelected, i, 1);
                            pc.turn := 1;
                          end else
                            AddMsg('����� ��� ����� ��� ����, ��� �� �������� ���-����!',0);
                        end;
                      end;
                  end;
                end;
              end;
            end;
          end;
        end;
      end;
      pc.AfterTurn;
    end;
  end;
end;

{ ��������� �������� }
procedure TMainForm.ProcessMsg;
begin
  Application.ProcessMessages;
end;

{ ��������� ���� }
procedure TMainForm.EndGame;
begin
  // ������� ����������
  DeleteSwap;
end;

{ ����� �� ���� }
procedure TMainForm.FormCloseQuery(Sender: TObject; var CanClose: Boolean);
begin
  CanClose := FALSE;
  if (pc.Hp <= 0) or (AskForQuit = False) then
  begin
    EndGame;
    CanClose := TRUE;
  end else
    if (GameState = gsPLAY) or (GameState = gsLOOK) or (GameState = gsCLOSE) or (GameState = gsCHOOSEMONSTER) then
    begin
      MenuSelected := 1;
      if (Ask('�������� ���, �������� ������? #(Y/n)#')) = 'Y' then
      begin
        CanClose := TRUE;
        EndGame;
      end else
        AddMsg('�� �����{/a} ������ ��� ����-����.',0);
    end else
      begin
//        if (GameState <> gsHEROGENDER) and (GameState <> gsHERONAME) then
//        begin
          ChangeGameState(gsPLAY);
          Redraw;
//        end;
      end;
end;

{ ���������� - �������� ���� }
procedure TMainForm.FormResize(Sender: TObject);
begin
  if GameState > 0 then
    Redraw;
end;

{ ��� �����, ��� �� TAB ���������� }
procedure TMainForm.CMDialogKey(var msg: TCMDialogKey);
begin
  if msg.Charcode <> VK_TAB then inherited;
end;

{ ��������� ������ }
procedure TMainForm.InitGame;
begin
  // ��������� ���� -> ����
  ChangeGameState(gsPLAY);
  AskForQuit := TRUE;
  // ����� � ��������� ��������
  GenerateColorAndStateOfLiquids;
  // ����� ������ �����������
  V.SetInt('PlayMode', PlayMode);
  case PlayMode of
    AdventureMode:  // ��������� �������
    begin
      pc.level := 1;
      M.MakeSpMap(pc.level);
      pc.PlaceHere(6,18);
      Run('InitStory.pas');
    end;
    DungeonMode:    // ���� � ����������
    begin
      pc.level := 7;
      M.MakeSpMap(pc.level);
      pc.PlaceHere(42,16);
      Run('InitStory.pas');
    end;
  end;
  pc.FOV;
  Addmsg(' ',0);
  Addmsg('����� (#F1#), ���� ����� ������.',0);
  Redraw;
end;

{ �������� �������� ������� }
procedure TMainForm.AnimFly(x1,y1,x2,y2:integer; symbol:string; color:byte);
var
  dx,dy,i,sx,sy,check,e,oldx,oldy:integer;
begin
  dx:=abs(x1-x2);
  dy:=abs(y1-y2);
  sx:=Sign(x2-x1);
  sy:=Sign(y2-y1);
  FlyX:=x1;
  FlyY:=y1;
  FlyS:=symbol;
  FlyC:=color;
  check:=0;
  if dy>dx then begin
      dx:=dx+dy;
      dy:=dx-dy;
      dx:=dx-dy;
      check:=1;
  end;
  e:= 2*dy - dx;
  for i:=0 to dx-1 do
  begin
    oldx := FlyX;
    oldy := FlyY;
    if e>=0 then
    begin
      if check=1 then FlyX:=FlyX+sx else FlyY:=FlyY+sy;
      e:=e-2*dx;
    end;
    if check=1 then FlyY:=FlyY+sy else FlyX:=FlyX+sx;
    e:=e+2*dy;
    // � ������ ��������� � ��� �����������
    if not TilesData[M.Tile[FlyX,FlyY]].void then
    begin
      // ���� ��������� ����� ��������� ����� �������
      break;
    end else
      // ����� ������
      if M.MonP[FlyX,FlyY] > 0 then
      begin
        autoaim := M.MonP[FlyY,FlyY];
        pc.Fire(M.MonL[M.MonP[FlyX,FlyY]]);
        break;
      end else
        begin
          Redraw;
          sleep(FlySpeed);
        end;
  end;
  FlyX := 0;
  FlyY := 0;
end;

procedure TMainForm.GameTimerTimer(Sender: TObject);
begin
  MainForm.Redraw;
end;

procedure TMainForm.FormDestroy(Sender: TObject);
begin
  KeyQueue.Free;
  ReleaseDC(MainForm.Handle, DC);
  DeleteDC(DC);
end;

procedure TMainForm.FormActivate(Sender: TObject);
begin
  StartGameMenu; //������� ������� ����
end;

procedure TMainForm.cls;
begin
  with _Screen.Canvas do
  begin
    Brush.Color := 0;
    FillRect(Rect(0, 0, MainForm.ClientRect.Right, MainForm.ClientRect.Bottom));
  end;
end;

procedure TMainForm.Redraw;
begin
  OnPaint(nil);
end;

procedure TMainForm.DrawString(x,y: byte; c: LongInt; s: string; l: byte = WindowX);
begin
  with _Screen.Canvas do
  begin
    Font.Color := c;
    TextOut(x * CharX, y * CharY, s);
//    log(inttostr(x*CharX)+','+inttostr(y*CharY)+','+s+'/'+inttostr(Font.Size));
  end;
end;

procedure TMainForm.SetFont(newFont: string);
begin
  with _Screen.Canvas do
  begin
    Font.Name := newFont;
    Font.Size := FontSize;
    case FontStyle of
      1:   Font.Style := [fsBold];
      2:   Font.Style := [fsItalic];
      3:   Font.Style := [fsBold, fsItalic];
      else Font.Style := [];
    end;
    CharX := TextWidth('W');
    CharY := TextHeight('W');
  end;
end;

procedure TMainForm.SetBgColor(c: Integer);
begin
  _Screen.Canvas.Brush.Color := c;
end;

procedure TMainForm.DrawHPBar(x, y: byte; color: Integer; hp, rhp: word);
begin
  with _Screen.Canvas do
  begin
    Pen.Color := cGRAY;
    Pen.Width := 3;
    MoveTo((x-1)*CharX+1, (y-1)*CharY - 2);
    LineTo((x)*CharX-1, (y-1)*CharY - 2);
    Pen.Color := cLIGHTRED;
    MoveTo((x-1)*CharX+1, (y-1)*CharY - 2);
    if M.MonP[x,y] = 1 then
    begin
      if pc.Hp > 0 then
        LineTo((x-1)*CharX+1 + Round( (pc.Hp * (CharX-2)) / pc.RHp), (y-1)*CharY - 2);
    end
    else
      if M.MonL[M.MonP[x,y]].Hp > 0 then
        LineTo((x-1)*CharX+1 + Round( (M.MonL[M.MonP[x,y]].Hp * (CharX-2))
             / M.MonL[M.MonP[x,y]].RHp), (y-1)*CharY - 2);
  end;
end;

procedure TMainForm.DrawString(x, y: byte; c: Integer; bs: TBrushStyle;
  s: string; l: byte = WindowX);
var OldStyle: TBrushStyle;
begin
  with _Screen.Canvas do
  begin
    OldStyle := Brush.Style;
    Brush.Style := bs;
    DrawString(x,y,c,s,l);
    Brush.Style := OldStyle;
  end;
end;

procedure TMainForm.DrawBar(x,y,l: word; c1,c2: LONGWORD); //��������� ����� ��������/����/�����/��� ����-��
var i,j: word;
  StartRGB, EndRGB: array[0..2] of Byte; // ����������� ����
  ax, ay, Colors, Delta: Word; // ����� ������, ������� ������������ ��� ���������
begin
  with _Screen.Canvas do
  begin
    Pen.Width := 9;
    ax :=  x*CharX+(CharX div 2);
    ay := y*CharY+(CharY div 2);
    if (c1 = c2)or(l<4) then
    begin
      Pen.Color := c2;
      MoveTo(ax, ay);
      LineTo(ax+l, ay);
    end
    else
    begin
      StartRGB[0] := GetRValue(c1);
      StartRGB[1] := GetGValue(c1);
      StartRGB[2] := GetBValue(c1);
      EndRGB[0] := GetRValue(c2);
      EndRGB[1] := GetGValue(c2);
      EndRGB[2] := GetBValue(c2);
      Colors := l div 2; // ����� �������� �� ������
      Delta := l div Colors; // ����� �������� ��� ����� ��������
      For i := 0 to Colors do
      begin
        Pen.Color := RGB((StartRGB[0] + MulDiv(i, EndRGB[0] - StartRGB[0], Colors-1)),
                         (StartRGB[1] + MulDiv(i, EndRGB[1] - StartRGB[1], Colors-1)),
                         (StartRGB[2] + MulDiv(i, EndRGB[2] - StartRGB[2], Colors-1)));
        MoveTo(ax+i*delta, ay);
        LineTo(ax+i*delta, ay);
      end;
    end;
  end;
end;

procedure TMainForm.HideCursor;
begin
  GameTimer.Enabled := false;
end;

procedure TMainForm.ShowCursor;
begin
  GameTimer.Enabled := true;
end;

initialization
  Randomize;
  // ������� �������� (�����)
  _Screen := TBitMap.Create;
  GrayScreen := TBitMap.Create;
  // �������� �������
  if (FontSize < 8 ) then FontSize := 8;
  if (FontSize > 20) then FontSize := 20;

finalization
  // ����������� �������� (�����)
  _Screen.Free;
  GrayScreen.Free;

end.
