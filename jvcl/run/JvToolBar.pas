{-----------------------------------------------------------------------------
The contents of this file are subject to the Mozilla Public License
Version 1.1 (the "License"); you may not use this file except in compliance
with the License. You may obtain a copy of the License at
http://www.mozilla.org/MPL/MPL-1.1.html

Software distributed under the License is distributed on an "AS IS" basis,
WITHOUT WARRANTY OF ANY KIND, either expressed or implied. See the License for
the specific language governing rights and limitations under the License.

The Original Code is: JvToolBar.PAS, released on 2001-02-28.

The Initial Developer of the Original Code is Sébastien Buysse [sbuysse@buypin.com]
Portions created by Sébastien Buysse are Copyright (C) 2001 Sébastien Buysse.
All Rights Reserved.

Contributor(s):
  Michael Beck [mbeck@bigfoot.com].
  Olivier Sannier [obones@meloo.com].

Last Modified: 2003-07-20

You may retrieve the latest version of this file at the Project JEDI's JVCL home page,
located at http://jvcl.sourceforge.net

Known Issues:
-----------------------------------------------------------------------------}

{$I JVCL.INC}

unit JvToolBar;

interface

uses
  Messages, SysUtils, Classes, Graphics, Controls, Forms, ComCtrls, Menus,
  JvTypes, JVCLVer, JvMenus;

type
  TJvToolBar = class(TToolBar)
  private
    FAboutJVCL: TJVCLAboutInfo;
    FChangeLink: TJvMenuChangeLink;
    FHintColor: TColor;
    FSaved: TColor;
    FOnMouseEnter: TNotifyEvent;
    FOnMouseLeave: TNotifyEvent;
    FOnParentColorChanged: TNotifyEvent;
    FOver: Boolean;
    {$IFNDEF COMPILER6_UP}
    FMenu: TMainMenu;
    {$ENDIF COMPILER6_UP}
    FTempMenu: TJvPopupMenu;
    FButtonMenu: TMenuItem;
    FMenuShowingCount: Integer;
    procedure ClearTempMenu;
    function GetMenu: TMainMenu;
    procedure SetMenu(const Value: TMainMenu);
    procedure MenuChange(Sender: TJvMainMenu; Source: TMenuItem; Rebuild: Boolean);
    procedure CMMouseEnter(var Msg: TMessage); message CM_MOUSEENTER;
    procedure CMMouseLeave(var Msg: TMessage); message CM_MOUSELEAVE;
    procedure CMParentColorChanged(var Msg: TMessage); message CM_PARENTCOLORCHANGED;
    procedure CNNotify(var Msg: TWMNotify); message CN_NOTIFY;
    procedure CNDropDownClosed(var Msg: TMessage); message CN_DROPDOWNCLOSED;
  protected
    procedure AdjustSize; override;
  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
  published
    property AboutJVCL: TJVCLAboutInfo read FAboutJVCL write FAboutJVCL stored False;
    property HintColor: TColor read FHintColor write FHintColor default clInfoBk;
    property Menu: TMainMenu read GetMenu write SetMenu;
    property OnMouseEnter: TNotifyEvent read FOnMouseEnter write FOnMouseEnter;
    property OnMouseLeave: TNotifyEvent read FOnMouseLeave write FOnMouseLeave;
    property OnParentColorChange: TNotifyEvent read FOnParentColorChanged write FOnParentColorChanged;
  end;

implementation

uses
  CommCtrl;

constructor TJvToolBar.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FHintColor := clInfoBk;
  FOver := False;
  FChangeLink := TJvMenuChangeLink.Create;
  FChangeLink.OnChange := MenuChange;
  ControlStyle := ControlStyle + [csAcceptsControls];
  FMenuShowingCount := 0;
end;

destructor TJvToolBar.Destroy;
begin
  if (Menu <> nil) and (Menu is TJvMainMenu) then
  begin
    TJvMainMenu(Menu).UnregisterChanges(FChangeLink);
  end;
  FChangeLink.Free;
  inherited Destroy;
end;

procedure TJvToolBar.CMMouseEnter(var Msg: TMessage);
begin
  FOver := True;
  FSaved := Application.HintColor;
  // for D7...
  if csDesigning in ComponentState then
    Exit;
  Application.HintColor := FHintColor;
  if Assigned(FOnMouseEnter) then
    FOnMouseEnter(Self);
end;

procedure TJvToolBar.CMMouseLeave(var Msg: TMessage);
begin
  Application.HintColor := FSaved;
  FOver := False;
  if Assigned(FOnMouseLeave) then
    FOnMouseLeave(Self);
end;

procedure TJvToolBar.CMParentColorChanged(var Msg: TMessage);
begin
  inherited;
  if Assigned(FOnParentColorChanged) then
    FOnParentColorChanged(Self);
end;

function TJvToolBar.GetMenu: TMainMenu;
begin
  {$IFDEF COMPILER6_UP}
  Result := inherited Menu;
  {$ELSE}
  Result := FMenu;
  {$ENDIF COMPILER6_UP}
end;

procedure TJvToolBar.SetMenu(const Value: TMainMenu);
begin
  // if trying to set the same menu, do nothing
  if Menu = Value then
    Exit;

  if Assigned(Menu) and (Menu is TJvMainMenu) then
  begin
    // if the current menu is a TJvMainMenu, we must
    // unregister us from being told the changes
    TJvMainMenu(Menu).UnregisterChanges(FChangeLink);
  end;

  if Value is TJvMainMenu then
  begin
    // if the new menu is a TJvMainMenu then we register a link
    // with the menu to get informed when it has changed
    TJvMainMenu(Value).RegisterChanges(FChangeLink);
  end;

  // and we set the inherited value, so that the inherited
  // methods can deal with the menu too, the most obvious
  // one being the creation of the required TToolButton
  {$IFDEF COMPILER6_UP}
  inherited Menu := Value;
  {$ELSE}
  FMenu := Value;
  {$ENDIF COMPILER6_UP}
end;

procedure TJvToolBar.MenuChange(Sender: TJvMainMenu; Source: TMenuItem; Rebuild: Boolean);
begin
  if Sender = Menu then
  begin
    // Compute our own value for rebuild, as the value passed
    // to us is not correct (see TJvMenuChangeLink for details)
    Rebuild := Menu.Items.Count <> ButtonCount;

    // if rebuild is necessary then
    if Rebuild then
    begin
      // force reloading menu by changing value twice
      // this is the only way of doing it as the creation of
      // the TToolButton is done in the original SetMenu in
      // TToolbar and this procedure is private
      Menu := nil;
      Menu := Sender;
    end;
  end;
end;

procedure TJvToolBar.AdjustSize;
var
  I: Integer;
  TotWidth: Integer;
begin
  inherited;

  // if there is a menu and the toolbar is not wrapable,
  // update width according to sum of button widths
  if (Menu <> nil) and not Wrapable then
  begin
    TotWidth := 0;
    for I := 0 to ButtonCount - 1 do
      TotWidth := TotWidth + Buttons[I].Width;
    Width := TotWidth;
  end;
end;

procedure TJvToolBar.ClearTempMenu;
var
  I: Integer;
  Item: TMenuItem;
begin
  if (FButtonMenu <> nil) and (FTempMenu <> nil) then
  begin
    for I := FTempMenu.Items.Count - 1 downto 0 do
    begin
      Item := FTempMenu.Items[I];
      FTempMenu.Items.Delete(I);
      FButtonMenu.Insert(0, Item);
    end;
    FTempMenu.Free;
    FTempMenu := nil;
    FButtonMenu := nil;
  end;
end;

procedure TJvToolBar.CNNotify(var Msg: TWMNotify);
var
  Button: TToolButton;
  JvParentMenu: TJvMainMenu;
  Menu: TMenu;
  I: Integer;
  Item: TMenuItem;
begin
  // we process the WM_NOTIFY message ourselves to be able to
  // display a dropdown JvMenu instead of a regular one.
  // However, we do that only if the menu is a TJvMainMenu and
  // if the code in WM_NOTIFY is TBN_DROPDOW. Anything else
  // is given back to the inherited method.
  // The code is mostly inspired from the Delphi 6 VCL source code,
  // the major change being the creation of a TJvPopupMenu
  // instead of a TPopupMenu.
  if Self.Menu is TJvMainMenu then
  begin
    with Msg do
    begin
      case NMHdr^.code of
        TBN_DROPDOWN:
          with PNMToolBar(NMHdr)^ do
            { We can safely assume that a TBN_DROPDOWN message was generated by a
              TToolButton and not any TControl. }
            if Perform(TB_GETBUTTON, iItem, Longint(@tbButton)) <> 0 then
            begin
              Button := TToolButton(tbButton.dwData);
              if (Button <> nil) then
              begin
                Button.MenuItem.Click;
                ClearTempMenu;
                FTempMenu := TJvPopupMenu.Create(nil);
                JvParentMenu := TJvMainMenu(Button.MenuItem.GetParentMenu);
                if JvParentMenu <> nil then
                  FTempMenu.BiDiMode := JvParentMenu.BiDiMode;
                FTempMenu.HelpContext := Button.MenuItem.HelpContext;
                FTempMenu.TrackButton := tbLeftButton;
                Menu := Button.MenuItem.GetParentMenu;
                if Menu <> nil then
                  FTempMenu.Assign(JvParentMenu);
                FButtonMenu := Button.MenuItem;
                for I := FButtonMenu.Count - 1 downto 0 do
                begin
                  Item := FButtonMenu.Items[I];
                  FButtonMenu.Delete(I);
                  FTempMenu.Items.Insert(0, Item);
                end;

                Button.DropdownMenu := FTempMenu;
                // for some reason, while the menu is showing,
                // it is possible that a second message comes
                // up and asks for the menu to show up.
                // so we keep track of that fact, and only when
                // the count comes back to 0, we hide the menu
                // in the CN_DROPDOWNCLOSED handler
                Inc(FMenuShowingCount);
                // show the temporary popup menu
                Button.CheckMenuDropdown;
              end;
            end;
      else
        inherited;
      end;
    end;
  end
  else
    inherited;
end;

procedure TJvToolBar.CNDropDownClosed(var Msg: TMessage);
begin
  if FMenuShowingCount = 1 then
    ClearTempMenu;
  Dec(FMenuShowingCount);
  inherited;
end;

end.

