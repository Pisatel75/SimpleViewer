unit MainForm;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Objects,
  FMX.Layouts, FMX.TreeView;

const
  SELDIRHELP = 1000;

type
  TForm1 = class(TForm)
    VertScrollBox1: TVertScrollBox;
    TreeView1: TTreeView;
    RoundRect1: TRoundRect;
    Text1: TText;
    procedure RoundRect1Click(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure TreeView1Change(Sender: TObject);
  private
    { Private declarations }
    function TreeConstruct(DirPath:String):Boolean;
  public
    { Public declarations }
  end;

  type
  LoadThumbnail = class(TThread)
  private
    { Private declarations }
  protected
    procedure Execute; override;
  end;

var
  Form1: TForm1;
  SelectedFolder:String;
  FoldersListNew,FilesList:TStringList;
  StartAndStop,StartAndStopWaiting,RunOfLoad:Boolean;
  ThreadOfLoadPictures:LoadThumbnail;

  function AddMainNode(TreeView:TTreeView;Name,Path:string;Tag:Integer):TTreeViewItem;
  function AddNode(TreeViewNode:TTreeViewItem;Name,Path:string;Tag:Integer):TTreeViewItem;
  function StartLoad:Boolean;
  function StopLoad:Boolean;

implementation

{$R *.fmx}

procedure TForm1.FormShow(Sender: TObject);
begin
  SelectedFolder:='C:\';
  FoldersListNew:=TStringList.Create;
  FoldersListNew.Sorted:=false;
  FoldersListNew.Duplicates:=dupIgnore;
  FoldersListNew.Clear;
  FilesList:=TStringList.Create;
  FilesList.Sorted:=false;
  FilesList.Duplicates:=dupIgnore;
  FilesList.Clear;
  RunOfLoad:=false;
end;

procedure TForm1.RoundRect1Click(Sender: TObject);
var
  i:Integer;
begin
  if SelectDirectory('Выберите папку с изображениями',SelectedFolder,SelectedFolder) then
    begin
      Text1.Text:=SelectedFolder;
      TreeConstruct(SelectedFolder);
      // Очищаем список пиктограмм
      if VertScrollBox1.ComponentCount>0 then
        begin
          // Список содержит хотя бы один компонент
          for i:=VertScrollBox1.ComponentCount-1 downto 0 do
            begin
              if not (VertScrollBox1.Components[i] is TRectangle) then
                begin
                  continue;
                end;
              if Assigned(VertScrollBox1.Components[i]) then
                begin
                  VertScrollBox1.Components[i].Free;
                end;
            end;
        end;
      TreeView1.Enabled:=true;
    end;
end;

function TForm1.TreeConstruct(DirPath:String):Boolean;
var
  i,j,k,m:Integer;
  WorkStr,WorkText,CurFolder:String;
  FlagZero,FlagFolder:Boolean;
  SearchRec:TSearchRec;
  FoldersList:TStringList;
  Node:TTreeViewItem;
begin
  try
    if DirectoryExists(DirPath) then
      begin
        // Строим структуру вложенных папок
        FoldersList:=TStringList.Create;
        FoldersList.Sorted:=false;
        FoldersList.Duplicates:=dupIgnore;
        FoldersList.Clear;
        FoldersList.Add(DirPath);
        FlagFolder:=true;
        While FlagFolder do
          begin
            FlagFolder:=false;
            i:=0;
            While i<=FoldersList.Count-1 do
              begin
                // Нашли необработанную папку
                FlagZero:=false;
                WorkText:=FoldersList[i];
                if FindFirst(WorkText+'\*.*',faAnyFile,SearchRec)=0 then
                  begin
                    repeat
                      if ((SearchRec.attr and faDirectory)=faDirectory) and
                         (SearchRec.Name<>'.') and (SearchRec.Name<>'..') then
                        begin
                          // Нашли вложенную папку, добавляем её в список
                          FoldersList.Add(WorkText+'\'+SearchRec.Name);
                          FlagZero:=true;
                          FlagFolder:=true;
                        end;
                    until FindNext(SearchRec)<>0;
                  end;
                FindClose(SearchRec);
                if FlagZero then
                  begin
                    // В папке найдены вложенные папки и они добавлены в список, удаляем исходную папку из списка
                    FoldersList.Delete(i);
                  end;
                Inc(i);
              end;
          end;
        // Строим дерево папок
        FoldersListNew.Clear;
        FoldersListNew.Add(DirPath);
        TreeView1.BeginUpdate;
        TreeView1.Clear;
        // Создание нулевого узла дерева
        Node:=AddMainNode(TreeView1,'TreeViewItem_0',DirPath,0);
        // Удаляем путь к корневой папке
        for i:=0 to FoldersList.Count-1 do
          begin
            FoldersList[i]:=StringReplace(FoldersList[i],DirPath+'\','',[rfReplaceAll]);
          end;
        if FoldersList.Count>1 then
          begin
            // Формируем ветви дерева
            j:=1;
            for i:=0 to FoldersList.Count-1 do
              begin
                // Строим каждую ветку отдельно
                WorkStr:=FoldersList[i];
                Node:=TreeView1.Items[0];
                Repeat
                  WorkText:=FoldersList[i];
                  if Pos('\',FoldersList[i])>0 then
                    begin
                      CurFolder:=Copy(WorkText,1,Pos('\',WorkText)-1);
                    end
                  else
                    begin
                      CurFolder:=WorkText;
                      FoldersList[i]:='';
                    end;
                  WorkText:=FoldersList[i];
                  Delete(WorkText,1,Pos('\',WorkText));
                  FoldersList[i]:=WorkText;
                  // Смотрим папку в текущем слое узлов дерева
                  FlagFolder:=true;
                  for k:=0 to Node.Count-1 do
                    begin
                      if Node.Items[k].Text=CurFolder then
                        begin
                          // Нашли папку в текущем слое
                          FlagFolder:=false;
                          m:=k;
                          Break;
                        end;
                    end;
                  if FlagFolder then
                    begin
                      // Папки нет, создаём её
                      Node:=AddNode(Node,'TreeViewItem_'+IntToStr(j),CurFolder,j);
                      FoldersListNew.Add(DirPath+'\'+StringReplace(WorkStr,FoldersList[i],'',[rfReplaceAll]));
                      Inc(j);
                    end
                  else
                    begin
                      Node:=Node.Items[m];
                    end;
                Until FoldersList[i]='';
              end;
          end;
        TreeView1.EndUpdate;
        FoldersList.Free;
      end
    else
      begin
        ShowMessage('ОШИБКА! Такой папки не существует: '+DirPath);
      end;
  except
    on E: Exception do
      begin
        ShowMessage(E.ClassName+': '+E.Message);
      end;
  end;
end;

procedure TForm1.TreeView1Change(Sender: TObject);
var
  i:Integer;
  WorkStr:String;
  SearchRec:TSearchRec;
  ParentRectangle:TRectangle;
  ImagePlace:TImage;
  ImageFileName:TText;
begin
  // Останавливаем загрузку пиктограмм если она запущена
  if RunOfLoad then
    begin
      RunOfLoad:=not StopLoad;
    end;
  if not RunOfLoad then
    begin
      WorkStr:=FoldersListNew[(Sender as TTreeView).Selected.Tag];
      if Copy(WorkStr,Length(WorkStr),1)='\' then
        begin
          Delete(WorkStr,Length(WorkStr),1);
        end;
      // Очищаем список пиктограмм
      if VertScrollBox1.ComponentCount>0 then
        begin
          // Список содержит хотя бы один компонент
          for i:=VertScrollBox1.ComponentCount-1 downto 0 do
            begin
              if not (VertScrollBox1.Components[i] is TRectangle) then
                begin
                  continue;
                end;
              if Assigned(VertScrollBox1.Components[i]) then
                begin
                  VertScrollBox1.Components[i].Free;
                end;
            end;
        end;
      // Строим список файлов для выбранной папки
      FilesList.Clear;
      if FindFirst(WorkStr+'\*.jpg',faAnyFile,SearchRec)=0 then
        begin
          repeat
            if (SearchRec.attr and faDirectory)<>faDirectory then
              begin
                // Нашли файл в текущей папке, добавляем его в список
                FilesList.Add(WorkStr+'\'+SearchRec.Name);
              end;
          until FindNext(SearchRec)<>0;
        end;
      if FindFirst(WorkStr+'\*.jpeg',faAnyFile,SearchRec)=0 then
        begin
          repeat
            if (SearchRec.attr and faDirectory)<>faDirectory then
              begin
                // Нашли файл в текущей папке, добавляем его в список
                FilesList.Add(WorkStr+'\'+SearchRec.Name);
              end;
          until FindNext(SearchRec)<>0;
        end;
      FindClose(SearchRec);
      if FindFirst(WorkStr+'\*.bmp',faAnyFile,SearchRec)=0 then
        begin
          repeat
            if (SearchRec.attr and faDirectory)<>faDirectory then
              begin
                // Нашли файл в текущей папке, добавляем его в список
                FilesList.Add(WorkStr+'\'+SearchRec.Name);
              end;
          until FindNext(SearchRec)<>0;
        end;
      FindClose(SearchRec);
      if FindFirst(WorkStr+'\*.png',faAnyFile,SearchRec)=0 then
        begin
          repeat
            if (SearchRec.attr and faDirectory)<>faDirectory then
              begin
                // Нашли файл в текущей папке, добавляем его в список
                FilesList.Add(WorkStr+'\'+SearchRec.Name);
              end;
          until FindNext(SearchRec)<>0;
        end;
      FindClose(SearchRec);
      // Формируем заготовку списка пиктограмм для выбранной папки
      for i:=0 to FilesList.Count-1 do
        begin
          // Контейнер для пиктограммы
          ParentRectangle:=TRectangle.Create(VertScrollBox1);
          ParentRectangle.Parent:=VertScrollBox1;
          ParentRectangle.Size.Width:=200;
          ParentRectangle.Size.Height:=220;
          ParentRectangle.Position.X:=0;
          // Место для пиктограммы
          ImagePlace:=TImage.Create(ParentRectangle);
          ImagePlace.Parent:=ParentRectangle;
          ImagePlace.Width:=150;
          ImagePlace.Height:=150;
          ImagePlace.Position.X:=25;
          ImagePlace.Position.Y:=25;
          ImagePlace.Tag:=i;
          // Имя файла
          ImageFileName:=TText.Create(ParentRectangle);
          ImageFileName.Parent:=ParentRectangle;
          ImageFileName.TextSettings.Font.Size:=13;
          ImageFileName.Align:=TAlignLayout.Bottom;
          ImageFileName.Margins.Left:=25;
          ImageFileName.Margins.Right:=25;
          ImageFileName.Text:=ExtractFileName(FilesList[i]);
          if i=0 then
            begin
              ParentRectangle.Align:=TAlignLayout.MostTop;
            end
          else
            begin
              ParentRectangle.Align:=TAlignLayout.Top;
              ParentRectangle.Margins.Top:=5;
            end;
        end;
      RunOfLoad:=StartLoad;
    end;
end;

function AddMainNode(TreeView:TTreeView;Name,Path:string;Tag:Integer):TTreeViewItem;
var
  Node:TTreeViewItem;
begin
  Node:=TTreeViewItem.Create(TreeView);
  Node.Name:=Name;
  Node.StyleLookup:='treeviewitemstyle';
  Node.Parent:=TreeView;
  Node.Text:=Path;
  Node.Tag:=Tag;
  Result:=Node;
end;

function AddNode(TreeViewNode:TTreeViewItem;Name,Path:string;Tag:Integer):TTreeViewItem;
var
  Node:TTreeViewItem;
begin
  Node:=TTreeViewItem.Create(TreeViewNode);
  Node.Name:=Name;
  Node.StyleLookup:='treeviewitemstyle';
  Node.Parent:=TreeViewNode;
  Node.Text:=Path;
  Node.Tag:=Tag;
  Result:=Node;
end;

procedure LoadThumbnail.Execute;
var
  ComponentNumber,i,CurTag:Integer;
begin
  StartAndStop:=true;
  StartAndStopWaiting:=false;
  while (not Terminated) and StartAndStop do
    begin
      if Form1.VertScrollBox1.ComponentCount>0 then
        begin
          // Список VertScrollBox1 содержит хотя бы один компонент
          if StartAndStop then
            begin
              for ComponentNumber:=0 to Form1.VertScrollBox1.ComponentCount-1 do
                begin
                  if not StartAndStop then
                    begin
                      StartAndStopWaiting:=true;
                      Break;
                    end;
                  if not (Form1.VertScrollBox1.Components[ComponentNumber] is TRectangle) then
                    begin
                      continue;
                    end;
                  if Assigned(Form1.VertScrollBox1.Components[ComponentNumber]) then
                    begin
                      for i:=0 to Form1.VertScrollBox1.Components[ComponentNumber].ComponentCount-1 do
                        begin
                          if not (Form1.VertScrollBox1.Components[ComponentNumber].Components[i] is TImage) then
                            begin
                              continue;
                            end;
                          if Assigned(Form1.VertScrollBox1.Components[ComponentNumber].Components[i]) then
                            begin
                              CurTag:=(Form1.VertScrollBox1.Components[ComponentNumber].Components[i] as Timage).Tag;
                              (Form1.VertScrollBox1.Components[ComponentNumber].Components[i] as Timage).
                              Bitmap.LoadThumbnailFromFile(FilesList[CurTag],150,150,true);
                            end;
                        end;
                    end;
                end;
              StartAndStop:=false;
              StartAndStopWaiting:=true;
            end;
        end;
    end;
    StartAndStopWaiting:=true;
end;

function StartLoad:Boolean;
begin
  try
    ThreadOfLoadPictures:=LoadThumbnail.Create(true);
    ThreadOfLoadPictures.Priority:=tpNormal;
    ThreadOfLoadPictures.Start;
    Sleep(500);
    Result:=true;
  except
    Result:=false;
  end;
end;

function StopLoad:Boolean;
begin
  try
    StartAndStop:=false;
    ThreadOfLoadPictures.Terminate;
    Sleep(500);
    ThreadOfLoadPictures.Free;
    Result:=true;
  except
    Result:=false;
  end;
end;

end.
