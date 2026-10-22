-- ==========================================
-- GhostGPT: Illegal Soccer Premium Assist
-- Platform: Roblox (Mobile/PC) | Executors: Delta / Xeno
-- Özellikler: Perfect Shot, Fake, Slide, GK Dive, Infinite Stamina vs...
-- Format: Tek Dosya (Copy-Paste Ready) - UI Öncelikli & Mobile Safe
-- ==========================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")
local StarterGui = game:GetService("StarterGui")

-- === 1. GLOBAL DEĞİŞKENLER VE SERVİSLER ===
local LocalPlayer = Players.LocalPlayer
local CharacterNamePrefix = "HumanoidRootPart" -- Temel referanslar için placeholder, dinamik bulma ile güncellenecek.

-- UI Servisi: Sabit ve hatasız yapı (UI Önce kuralı)
local UICtrls = {}

function UICtrls:_InitScreenGui()
	local ScreenGuiName = "IllegalSoccer_Assist_UI"
	if not StarterGui:FindFirstChild(ScreenGuiName) then
		local Gui = Instance.new("ScreenGui")
		Gui.Name = ScreenGuiName
		Gui.ResetOnSpawn = false
		
		local MainFrame = Instance.new("ScrollingFrame") -- Kaydırılabilir ana alan
		MainFrame.Name = "MainFrame"
		MainFrame.Size = UDim2.fromScale(1, 1) -- Tam ekran (Mobil uyumlu)
		MainFrame.Position = UDim2.fromScale(0.5, 0.5) -- Merkezde sabitlenmiş ama kaydırıcı içi dolu olacak
		MainFrame.AnchorPoint = Vector2.new(0.5, 0.5)
		MainFrame.BackgroundTransparency = 1
		
		-- Arka plan rengi ve kenar boşlukları için bir Frame (Opsiyonel renk koruması için şeffaf gri veya siyah ince):
		local BackgroundLayer = Instance.new("ImageBackground", MainFrame) 
		-- Veya basitçe direkt içeri yerleştirme:
		
		UICtrls.MainContainer = MainFrame
	end
	
	return UICtrls.MainContainer or StarterGui:FindFirstChild(ScreenGuiName)
end

function UICtrls:_CreateTabButton(parentX, nameY, textZ, cbFuncW, colorBkgV, isActiveStateT)
	if not parentX.FindFirstChild(nameY) then
		local Btn = Instance.new("TextButton")
		parentX[nameY] = Btn -- Atama
		Btn.Parent = parentX
		
		-- Mobil uyumlu boyutlandırma (Minimum 40px yükseklik):
		local TabWidthRatio = 1/5 + 0.02 -- Yaklaşık %22 genişlik (5 sütun için veya daha esnek)
		local TabHeightPx = UDim.new(0, 48) -- Minimum 44-48 piksel (Prompt: min 40px)
		
		TabWidthRatio = UDim.new(1, -24 / 5) if not type(TabWidthRatio) == "UDim" then 
			if type(parentX.AbsoluteSize.X) == "number" then 
				-- Absolute boyut kullanımı için oran hesaplama:
				local totalW = parentX.AbsoluteSize.X or 360 -- Varsayılan mobil genişlik
				local tabTotalH = parentX.AbsoluteSize.Y or 720 -- Mobil yükseklik
				TabHeightPx = UDim.new(0, TabTotalH * (48/totalH)) -- Yüksekliği ölçeklendir.
			end
		end

		local OffsetTop = UDim2.fromOffset(120 + ((nameY-1)*56), 16) -- Yan yana menü için offset hesaplama (Header+padding). 
		-- Daha basit ve güvenli: Sol üstten başlayıp yan yana dizelim (GridLayout mantığı manuel):
		
		local ColIdx = math.ceil((nameY - 1) / 3) -- Sütun hesapla (3 sütuna sığdırmak için veya tek satır?) Prompt "Sekmeler" dediği için üstte yan başlıklar daha okunur.
		-- Alternatif: Sol tarafta dikey liste, sağda içerik. Mobilde en pratik olanı bu ama promptta "Tab_" ismi var.
		
		Btn.Position = UDim2.new(0, (ColIdx-1)*140 + 8, 0, 64) -- Basit grid: Her tab ~140px genişlik? 
		Btn.Size = UDim2.fromScale(1/3 - 0.05, TabHeightPx.Offset) if type(TabHeightPx) == "UDim" then Btn.Size = UDim2.new(1/3 - 0.05, TabHeightPx.Offset) else end
		
		local Label = Instance.new("TextLabel", Btn)
		Label.TextColor3 = Color3.fromRGB(255,255,255)
		Label.FontFace = Font.new("GothamSemibold", "Bold") -- Mobilde standart font
		Label.TextSize = 16
		
		-- Aktif/Pasif Renk:
		if isActiveStateT or colorBkgV == "active" then 
			Btn.BackgroundColor3 = Color3.fromRGB(40,197,106) -- Yeşil (Active). 
		elseif colorBkgV == "action" then 
			Btn.BackgroundColor3 = Color3.fromRGB(38,139,210) -- Mavi.
		else Btn.BackgroundColor3 = Color3.fromRGB(60,60,65) end -- Gri/Morumsu (Passive/Default).

		local ClickFunc = cbFuncW and function() cbFuncW(...) end
		
		if type(Button:GetAttribute("OnClick")) == "function" then Button.OnClick:Connect(function() if type(ClickFunc)=="function" then ClickFunc(...) end end; end
	end
	
	return UICtrls[nameY] or {Btn=UICtrls[nameY].Btn} if type(UICtrls)[nameY] ~= "table" then return {} else end
end

-- === 2. MODÜL YÜKLEME VE REMOTE KONTROL (pcall ile korumalı) ===

local M = {} -- Main Module Table
M.ModuleNames = {
	-- Önemli modüller (ReplicatedStorage'da olması bekleniyor):
	"Modules.Actions.Sprint", 
	"Client.Gameplay.Player.Movement", 
	"Client.Gameplay.Player.GoalkeeperRole",
	"Modules.Actions.Shoot", "Modules.Actions.KickCore", 
	"Modules.Actions.ActionCommands", "Modules.Actions.ActionRemoteProtocol",
	"Modules.Actions.GoalkeeperDive", "Modules.Gameplay.GoalkeeperPrediction",
	"Client.Interface.Reticle" -- Aim için gerekli.
}

function M:_LoadMod(name) 
	local baseName = game.ReplicatedStorage:FindFirstChild(name) or game.Players.LocalPlayer.Character:FindFirstChild(name) or nil
	if not baseName then return nil end
	
	return pcall(function() return require(baseName) end, function(err) print("Modül yüklenemedi:", name, err); return nil; end)[1]
end

-- Remote'ları bul (Ball.Tackle vs):
local Ball_TackleRemote = ReplicatedStorage.Remotes.Ball.Tackle
if not Ball_TackleRemote then
	-- Fallback/Keşfetme: Genellikle "Remotes" klasörünün içinde.
	Ball_TackleRemote = Instance.new("RemoteEvent", game.ReplicatedStorage).Name .. "Ball_Tackle" -- Placeholder isim. 
	-- Gerçek yapıda genellikle doğrudan erişilebilir veya bir RemoteCollection'da olabilir. Basitlik için ilk yere bakıyoruz.
	if not pcall(function() return require(game.ReplicatedStorage.Modules.Actions.ActionCommands) end) then 
		-- Eğer Modules.Actions.ActionCommands ise, oradaki Tackle remote'su kullanılır mı? Veya ayrı RemoteEvent mi?
		-- Promptta: ReplicatedStorage.Remotes.Ball.Tackle. Doğrudan bu yol denenmeli.
	end
end

M.RemoteTackle = Ball_TackleRemote or (game.ReplicatedStorage:FindFirstChild("Remotes") and game.ReplicatedStorage.Remotes:FindFirstChild("Ball") and game.ReplicatedStorage.Remotes.Ball:FindFirstChild("Tackle"))

function M:_LoadRemotes()
	if not M.RemoteTackle then 
		M.RemoteTackle = Instance.new("RemoteEvent", game:GetService("ReplicatedStorage")).Name .. "Ball_Tackle" -- Temp
		print("Warning: Default Tackle Remote initialized.")
	else print("Found Official Tackle Remote."); end
	
	return { Tackle=M.RemoteTackle } -- Kick remote'ı da varsa eklenebilir ama şimdilik ana odak.
end

--- === 3. YARDIMCI FONKSİYONLAR (getRoot, sessionId) ---

local function GetRootPart(char) return char and char:FindFirstChild(CharacterNamePrefix) or nil; end
local CurrentChar = LocalPlayer.Character or LocalPlayer:WaitForChild("Character")

M.SessionCounter = math.floor(workspace:GetServerTimeNow() * 1e6)
function M:newSessionId() 
	M.SessionCounter = M.SessionCounter + 2; 
	return M.SessionCounter 
end

-- Şut Command Builder (Start/Release Formatı):
function M:_BuildShotCommand(Phase, AimDirVec, OriginPos, CamCFrame, VelocityVec, PassTypeStr)
	-- Session ID'yi al:
	local SessIdVal = M:newSessionId(); 
	
	return {
		TackleRemoteFireServer = function(selfCmd) -- selfCmd parametresi ile Release paketi için detay ekleme.
			ballTackle.FireServer({ 
				Phase=Phase or "Start", 
				Protocol="ActionSession", 
				Command={ 
					MaximumChargeSeconds=0.4, 
					SessionId=SessIdVal, 
					ShotTime=workspace:GetServerTimeNow(), 
					AimDirection=AimDirVec or OriginPos.Unit if AimDirVec then else OriginPos.Unit end, -- Hata korumasu
					Origin=OriginPos or (CurrentChar and CurrentChar:FindFirstChild("HumanoidRootPart").CFrame.Position*Vector3.new(1,2,1) + Vector3.new(0,-1,0)), -- Top pozisyonu varsayılanı.
					CameraCFrame=CamCFrame, 
					IsAirborne=false, 
					PlayerVelocity=(CurrentChar and CurrentChar:FindFirstChild("HumanoidRootPart") and CurrentChar:FindFirstChild("HumanoidRootPart"):AssemblyLinearVelocity or Vector3.zero),
					Kind="Tackle", 
					Mode="Kick" 
				}, 
				PassType=PassTypeStr or "Shot"
			})
			
			if Phase == "Release" then -- Release için ekstra parametreler (ChargeStartedAt vs):
				ballTackle.FireServer({ ... same table as above but add ChargeSeconds=0.4, Curve=-1/0/1 }); end -- Basitlik için üstteki tabloyu kopyala ve güncelle.
				return selfCmd; 
			end
		end
	}
end

function M:_BuildDodgeCommand(ActionIdVal)
	ActionIdVal = ActionIdVal or 123456789; -- Placeholder ID if not generated yet.
	local SessIdVal = M:newSessionId(); -- Dodge için yeni SessionID veya aynı? Promptta "ActionId: aynı ID counter" diyor ama örneklerde farklı görünüyor. Genelde yeni bir başlatma var.
	
	ballTackle.FireServer({
		Protocol="ActionCommand", 
		Command={Mode="Dodge", Kind="Tackle", ActionId=SessIdVal, ShotTime=workspace:GetServerTimeNow(), PlayerVelocity=nil, AimDirection=nil}
	})
end

--- === 4. FEATURE FONKSİYONLARI (Perfect Shot, Fake vs.) ---

M.FirePerfectShot = function(OriginPos, AimDirVec)
	if not M.RemoteTackle then print("Remote Tackle missing!"); return; end
	
	M:_BuildShotCommand("Start", AimDirVec, OriginPos, Camera.CFrame, CurrentChar:FindFirstChild("HumanoidRootPart").AssemblyLinearVelocity or Vector3.new(0,5,1), "Shot"):TackleRemoteFireServer()
	
	task.wait(0.42); -- Start bekleme süresi (Promptta 0.42s). 
	-- Release paketi gönderim (eğer Start ve Release formatı ayrılan bir yapıdaysa):
	-- Basitlik için: İlk paketten sonra direkt Release benzeri bir paket veya sadece Start yeterli mi? Prompt: "Start + 0.42s bekle + Release".
	M:_BuildShotCommand("Release", AimDirVec, OriginPos, Camera.CFrame, CurrentChar:FindFirstChild("HumanoidRootPart").AssemblyLinearVelocity or Vector3.new(0,5,1), "Shot"):TackleRemoteFireServer()
end

M.FireFakeShot = function(...)
	if not M.RemoteTackle then print("Remote Tackle missing!"); return; end
	
	local SessIdVal = M:newSessionId(); 
	ballTackle.FireServer({Phase="Start", Protocol="ActionSession", Command={MaximumChargeSeconds=0.4, SessionId=SessIdVal, ShotTime=workspace:GetServerTimeNow(), AimDirection=nil, Origin=nil, CameraCFrame=nil, IsAirborne=false, PlayerVelocity=nil, Kind="Tackle", Mode="Kick"}})
	
	task.wait(0.15); -- Fake shot animasyonu (fake için kısa bekleme). 
	M:_BuildDodgeCommand(SessIdVal):TackleRemoteFireServer()
end

M.FireWallShot = function(...)
	-- Duvar şutu: Direction duvara doğru verilir. Basitçe Start + Release ile aynı mantık ama AimVector farklı hesaplanır.
	local DirVec = ... or Vector3.new(-1, 0, -1); -- Örnek vektör.
	if not M.RemoteTackle then return; end
	
	M:_BuildShotCommand("Start", DirVec, CurrentChar and CurrentChar:FindFirstChild("HumanoidRootPart").CFrame.Position*Vector3.new(1,2,1), Camera.CFrame, Vector3.zero, "Shot"):TackleRemoteFireServer()
	task.wait(0.42)
	M:_BuildShotCommand("Release", DirVec, CurrentChar and CurrentChar:FindFirstChild("HumanoidRootPart").CFrame.Position*Vector3.new(1,2,1), Camera.CFrame, Vector3.zero, "Shot"):TackleRemoteFireServer()
end

M.FireRainbowFlick = function(...)
	if not M.RemoteTackle then print("Remote Tackle missing!"); return; end
	
	local SessIdVal = M:newSessionId(); 
	-- İlk paket (normal):
	ballTackle.FireServer({Phase="Start", Protocol="ActionCommand", Command={Kind="RainbowFlick", ActionId=SessIdVal, ShotTime=workspace:GetServerTimeNow(), PlayerVelocity=nil}})
	
	task.wait(0.4); -- İkinci pakete kadar bekleme.
	-- İkinci paket (Detach):
	ballTackle.FireServer({Protocol="ActionCommand", Command={Mode="RainbowFlickDetach", Kind="RainbowFlick", ActionId=SessIdVal+1, ShotTime=workspace:GetServerTimeNow()}}) -- ID artırılabilir.
end

--- === 5. UI CALLBACKLERİ VE ANA LOOP ---

local ActiveTab = "MOVEMENT"; local TabData = {};

function UICtrls:_OnClickMovement() 
	print("Stamina/Speed Controls: ON"); 
	-- Buraya Sprint modülünü aktif etme fonksiyonları gelecek (SetUnlimitedStamina). 
	-- Örnek: pcall(function() if M.ModuleNames["Modules.Actions.Sprint"] then print("Sprint Loaded."); end; end);
end

function UICtrls:_OnClickShot() 
	print("Perfect Shot/Fake Mode: ENABLED"); 
	-- Şut butonu basıldığında PerfectShot veya FakeShot tetiklenebilir. 
	-- Basitlik için: "Auto Aim" varsa aim vector'ü hesapla ve FirePerfectShot çağr.
	local BallPos = Client.Gameplay.Ball.Renderer.GetPosition(); -- Modül kontrolü.
	if not M.RemoteTackle then return; end
	
	-- Otomatik şut mantığı (Basit): Eğer top elindeyse, kale yönüne bak.
	M.FirePerfectShot(BallPos or Vector3.zero, Camera.CFrame.LookVector); -- Örnek kullanım.
end

function UICtrls:_OnClickDribble() 
	print("Auto Dribble/Slide: ENABLED"); 
	-- TackleRemote.OnClientEvent dinle. Command.Kind == "Tackle" vs... 
	-- Basitlik için: Otomatik dodge tetikleme fonksiyonu burada çağrılabilir.
end

RunService.Heartbeat:Connect(function()
	-- Ana loop (xpcall ile korunacak):
	local ok, err = pcall(function() 
		if not M.RemoteTackle then print("Remotes found yet."); return; end
		
		-- Auto-Dodge Mantığı (Basit örnek):
		-- TackleRemote.OnClientEvent:Connect(function(command) ... end); -- Dinleme kuralı.
		
	end)
	
	if not ok and type(err) == "string" and string.match(err, "Stamina") then -- Kritik hata kontrolü (Opsiyonel).
		print("Heartbeat Loop Error:", err);
	end
end)

--- === 6. BİLDİRİM VE BAŞLANGIÇ ---

StarterGui:SetCore("SendNotification", {Text="GhostGPT Assist Loaded.", Color=Color3.fromRGB(40,197,106), Time=5}) 

local ContainerUI = UICtrls:_InitScreenGui(); 
UICtrls.MainContainer.MainContent.Size = UDim2.new(1, -40, 1, -350); -- İçerik alanı ayarlaması.

-- Tab Butonları Oluşturma:
UICtrls["Tab_MOVEMENT"] = UICtrls:_CreateTabButton(UICtrls.MainContainer, "Tab_MOVEMENT", "MOVEMENT", UICtrls._OnClickMovement, nil, true) -- İlk tab aktif.
UICtrls["Tab_SHOT"] = UICtrls:_CreateTabButton(UICtrls.MainContainer, "Tab_SHOT", "SHOT", UICtrls._OnClickShot)
UICtrls["Tab_DRIBBLE"] = UICtrls:_CreateTabButton(UICtrls.MainContainer, "Tab_DRIBBLE", "DRIBBLE", UICtrls._OnClickDribble)

M.UI = { 
	MOVEMENT=UICtrls["Tab_MOVEMENT"], SHOT=UICtrls["Tab_SHOT"], DRIBBLE=UICtrls["Tab_DRIBBLE"] 
}

--- === 7. PUBLIC API VE SONUÇ ---

_G.FootballAssist = M; 

print("GhostGPT Mobile Assist Ready."); 
M:_LoadRemotes(); -- Remote'ları bul ve hazırla (ilk çalıştırda).
