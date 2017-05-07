--dofile("../data/addon_d/camcon/camcon.lua");

--アドオン名（大文字）
local addonName = "CAMCON";
local addonNameLower = string.lower(addonName);
--作者名
local author = "SUZUMEIKO";

--アドオン内で使用する領域を作成。以下、ファイル内のスコープではグローバル変数gでアクセス可
_G["ADDONS"] = _G["ADDONS"] or {};
_G["ADDONS"][author] = _G["ADDONS"][author] or {};
_G["ADDONS"][author][addonName] = _G["ADDONS"][author][addonName] or {};
local g = _G["ADDONS"][author][addonName];

--設定ファイル保存先
g.settingsFileLoc = string.format("../addons/%s/settings.json", addonNameLower);

--設定値
g.settings = {
	enable = true,
	position = {
		x = 500,
		y = 500
	},
	campos = {
		x = 45,
		y = 38,
		z = 236
	}
};
g.master = {
	max = {
		x = 360,
		y = 90,
		z = 700
	},
	default = {
		x = 45,
		y = 38,
		z = 236
	}
};

--ライブラリ読み込み
local acutil = require('acutil');

--lua読み込み時のメッセージ
CHAT_SYSTEM("[ADDON] camcon loaded");

--マップ読み込み時処理（1度だけ）
function CAMCON_ON_INIT(addon, frame)
	g.addon = addon;
	g.frame = frame;

	frame:ShowWindow(0);
	acutil.slashCommand("/camcon", CAMCON_TOGGLE_FRAME);
	if not g.loaded then
		local t, err = acutil.loadJSON(g.settingsFileLoc, g.settings);
		if err then
			--設定ファイル読み込み失敗時処理
			--CHAT_SYSTEM("[camcon] 設定ファイルのロードに失敗");
		else
			--設定ファイル読み込み成功時処理
			--CHAT_SYSTEM("[camcon] 設定ファイルのロードに成功");
			g.settings = t;
			g.loaded = true;
		end
	end
	if g.settings.enable then
		frame:ShowWindow(1);
	end

	--ドラッグ
	frame:EnableHitTest(1);
	frame:SetEventScript(ui.LBUTTONUP, "CAMCON_END_DRAG");

	frame:Move(g.settings.position.x, g.settings.position.y);
	frame:SetOffset(g.settings.position.x, g.settings.position.y);

	--フレーム初期化処理
	CAMCON_INIT_FRAME(frame);
end

function CAMCON_SAVE_SETTINGS()
	acutil.saveJSON(g.settingsFileLoc, g.settings);
end


function CAMCON_INIT_FRAME(frame)
  --フレーム初期化処理
	local frame = ui.GetFrame("camcon");
	frame:SetSkinName("box_glass");
	
	local titleText = frame:CreateOrGetControl("richtext", "n_titleText", 0, 0, 0, 0);
	titleText:SetOffset(10,10);
	titleText:SetFontName("white_16_ol");
	titleText:SetText("カメラコントロール /camcon");
	
	local tipText = frame:CreateOrGetControl("richtext", "n_tip", 0, 0, 0, 0);
	tipText:SetOffset(10,120);
	tipText:SetFontName("white_12_ol");
	tipText:SetText("Z座標範囲外時、XY弄ると戻るのはclient仕様です");
	
	local btnReset = frame:CreateOrGetControl("button", "n_reset", 240, 4, 56, 30);
	btnReset:SetText("{@sti7}{s16}RESET");
	btnReset:SetEventScript(ui.LBUTTONUP, "CAMCON_RESET");
	
	local labelX = frame:CreateOrGetControl("richtext", "n_labelX", 0, 0, 0, 0);
	labelX:SetOffset(20,40);
	labelX:SetFontName("white_14_ol");
	labelX:SetText("X座標("..(g.settings.campos.x).."):");
	
	local labelY = frame:CreateOrGetControl("richtext", "n_labelY", 0, 0, 0, 0);
	labelY:SetOffset(20,70);
	labelY:SetFontName("white_14_ol");
	labelY:SetText("Y座標("..(g.settings.campos.y).."):");
	
	local labelZ = frame:CreateOrGetControl("richtext", "n_labelZ", 0, 0, 0, 0);
	labelZ:SetOffset(20,100);
	labelZ:SetFontName("white_14_ol");
	labelZ:SetText("Z座標("..(g.settings.campos.z).."):");
	
	local scrX = frame:CreateOrGetControl("slidebar", "n_scrX", 120, 34, 180, 30);
	tolua.cast(scrX, 'ui::CSlideBar');
	scrX:SetMinSlideLevel(0);
	scrX:SetMaxSlideLevel(g.master.max.x-1);
	scrX:SetLevel(g.master.default.x);
	
	local scrY = frame:CreateOrGetControl("slidebar", "n_scrY", 120, 64, 180, 30);
	tolua.cast(scrY, 'ui::CSlideBar');
	scrY:SetMinSlideLevel(-89);
	scrY:SetMaxSlideLevel(g.master.max.y-1);
	scrY:SetLevel(g.master.default.y);
	
	local scrZ = frame:CreateOrGetControl("slidebar", "n_scrZ", 120, 94, 180, 30);
	tolua.cast(scrZ, 'ui::CSlideBar');
	scrZ:SetMinSlideLevel(50);
	scrZ:SetMaxSlideLevel(g.master.max.z);
	scrZ:SetLevel(g.master.default.z);
	
end

--カメラ座標リセット
function CAMCON_RESET()
	local frame = ui.GetFrame("camcon");
	local scrX = frame:GetChild("n_scrX");
	local scrY = frame:GetChild("n_scrY");
	local scrZ = frame:GetChild("n_scrZ");
	tolua.cast(scrX, 'ui::CSlideBar');
	tolua.cast(scrY, 'ui::CSlideBar');
	tolua.cast(scrZ, 'ui::CSlideBar');
	
	g.settings.campos.x=g.master.default.x;
	g.settings.campos.y=g.master.default.y;
	g.settings.campos.z=g.master.default.z;
	scrX:SetLevel(g.master.default.x);
	scrY:SetLevel(g.master.default.y);
	scrZ:SetLevel(g.master.default.z);
	
	-- UPDATE
	CAMCON_CAMERA_UPDATE_Z();
	CAMCON_CAMERA_UPDATE_XY();
end

--カメラ座標切り替え
function CAMCON_CAMERA_UPDATE_XY()
	local frame = ui.GetFrame("camcon");
	local labelX = frame:GetChild("n_labelX");
	local scrX = frame:GetChild("n_scrX");
	local labelY = frame:GetChild("n_labelY");
	local scrY = frame:GetChild("n_scrY");
	tolua.cast(scrX, 'ui::CSlideBar');
	tolua.cast(scrY, 'ui::CSlideBar');

	g.settings.campos.x = scrX:GetLevel();
	g.settings.campos.y = scrY:GetLevel();

	labelX:SetText("X座標("..(g.settings.campos.x).."):");
	labelY:SetText("Y座標("..(g.settings.campos.y).."):");

	-- UPDATE
	camera.CamRotate(g.settings.campos.y, g.settings.campos.x);
end

--カメラ座標切り替え
function CAMCON_CAMERA_UPDATE_Z()
	local frame = ui.GetFrame("camcon");
	local labelZ = frame:GetChild("n_labelZ");
	local scrZ = frame:GetChild("n_scrZ");
	tolua.cast(scrZ, 'ui::CSlideBar');

	g.settings.campos.z = scrZ:GetLevel();

	labelZ:SetText("Z座標("..(g.settings.campos.z).."):");

	-- UPDATE
	camera.CustomZoom(g.settings.campos.z);
end

  
--フレーム場所保存処理
function CAMCON_END_DRAG()
	g.settings.position.x = g.frame:GetX();
	g.settings.position.y = g.frame:GetY();
	CAMCON_SAVE_SETTINGS();
end

--フレームの表示切り替え
function CAMCON_TOGGLE_FRAME()
	local frame = ui.GetFrame("camcon");
	if g.settings.enable == true then
		frame:ShowWindow(0);
		g.settings.enable=false;
	else
		frame:ShowWindow(1);
		g.settings.enable=true;
	end
end
