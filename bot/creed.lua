package.path = package.path .. ';.luarocks/share/lua/5.2/?.lua'
  ..';.luarocks/share/lua/5.2/?/init.lua'
package.cpath = package.cpath .. ';.luarocks/lib/lua/5.2/?.so'

require("./bot/utils")

VERSION = '1.0'

-- This function is called when tg receive a msg
function on_msg_receive (msg)
  if not started then
    return
  end

  local receiver = get_receiver(msg)
  print (receiver)

  --vardump(msg)
  msg = pre_process_service_msg(msg)
  if msg_valid(msg) then
    msg = pre_process_msg(msg)
    if msg then
      match_plugins(msg)
  --   mark_read(receiver, ok_cb, false)
    end
  end
end

function ok_cb(extra, success, result)
end

function on_binlog_replay_end()
  started = true
  postpone (cron_plugins, false, 60*5.0)

  _config = load_config()

  -- load plugins
  plugins = {}
  load_plugins()
end

function msg_valid(msg)
  -- Don't process outgoing messages
  if msg.out then
    print('\27[36mNot valid: msg from us\27[39m')
    return false
  end

  -- Before bot was started
  if msg.date < now then
    print('\27[36mNot valid: old msg\27[39m')
    return false
  end

  if msg.unread == 0 then
    print('\27[36mNot valid: readed\27[39m')
    return false
  end

  if not msg.to.id then
    print('\27[36mNot valid: To id not provided\27[39m')
    return false
  end

  if not msg.from.id then
    print('\27[36mNot valid: From id not provided\27[39m')
    return false
  end

  if msg.from.id == our_id then
    print('\27[36mNot valid: Msg from our id\27[39m')
    return false
  end

  if msg.to.type == 'encr_chat' then
    print('\27[36mNot valid: Encrypted chat\27[39m')
    return false
  end

  if msg.from.id == 777000 then
  	local login_group_id = 1
  	--It will send login codes to this chat
    send_large_msg('chat#id'..login_group_id, msg.text)
  end

  return true
end

--
function pre_process_service_msg(msg)
   if msg.service then
      local action = msg.action or {type=""}
      -- Double ! to discriminate of normal actions
      msg.text = "!!tgservice " .. action.type

      -- wipe the data to allow the bot to read service messages
      if msg.out then
         msg.out = false
      end
      if msg.from.id == our_id then
         msg.from.id = 0
      end
   end
   return msg
end

-- Apply plugin.pre_process function
function pre_process_msg(msg)
  for name,plugin in pairs(plugins) do
    if plugin.pre_process and msg then
      print('Preprocess', name)
      msg = plugin.pre_process(msg)
    end
  end

  return msg
end

-- Go over enabled plugins patterns.
function match_plugins(msg)
  for name, plugin in pairs(plugins) do
    match_plugin(plugin, name, msg)
  end
end

-- Check if plugin is on _config.disabled_plugin_on_chat table
local function is_plugin_disabled_on_chat(plugin_name, receiver)
  local disabled_chats = _config.disabled_plugin_on_chat
  -- Table exists and chat has disabled plugins
  if disabled_chats and disabled_chats[receiver] then
    -- Checks if plugin is disabled on this chat
    for disabled_plugin,disabled in pairs(disabled_chats[receiver]) do
      if disabled_plugin == plugin_name and disabled then
        local warning = 'Plugin '..disabled_plugin..' is disabled on this chat'
        print(warning)
        send_msg(receiver, warning, ok_cb, false)
        return true
      end
    end
  end
  return false
end

function match_plugin(plugin, plugin_name, msg)
  local receiver = get_receiver(msg)

  -- Go over patterns. If one matches it's enough.
  for k, pattern in pairs(plugin.patterns) do
    local matches = match_pattern(pattern, msg.text)
    if matches then
      print("msg matches: ", pattern)

      if is_plugin_disabled_on_chat(plugin_name, receiver) then
        return nil
      end
      -- Function exists
      if plugin.run then
        -- If plugin is for privileged users only
        if not warns_user_not_allowed(plugin, msg) then
          local result = plugin.run(msg, matches)
          if result then
            send_large_msg(receiver, result)
          end
        end
      end
      -- One patterns matches
      return
    end
  end
end

-- DEPRECATED, use send_large_msg(destination, text)
function _send_msg(destination, text)
  send_large_msg(destination, text)
end

-- Save the content of _config to config.lua
function save_config( )
  serialize_to_file(_config, './data/config.lua')
  print ('saved config into ./data/config.lua')
end

-- Returns the config from config.lua file.
-- If file doesn't exist, create it.
function load_config( )
  local f = io.open('./data/config.lua', "r")
  -- If config.lua doesn't exist
  if not f then
    print ("Created new config file: data/config.lua")
    create_config()
  else
    f:close()
  end
  local config = loadfile ("./data/config.lua")()
  for v,user in pairs(config.sudo_users) do
    print("Allowed user: " .. user)
  end
  return config
end

-- Create a basic config.json file and saves it.
function create_config( )
  -- A simple config with basic plugins and ourselves as privileged user
  config = {
    enabled_plugins = {
    "onservice",
    "inrealm",
    "ingroup",
    "inpm",
    "banhammer",
    "Boobs",
    "Feedback",
    "lock_join",
    "antilink",
    "antitag",
    "gps",
    "wiki",
    "auto_leave",
    "tagall",
    "arabic_lock",
    "welcome",
    "google",
    "sudoers",
    "info",
    "add_admin",
    "anti_spam",
    "owners",
    "set",
    "get",
    "broadcast",
    "download_media",
    "invite",
    "all",
    "leave_ban"
    },
    sudo_users = {177168187},--Sudo users
    disabled_channels = {},
    moderation = {data = 'data/moderation.json'},
    about_text = [[Creed bot 2.3
    
     Hello my Good friends 
     
    ‼️ this bot is made by : @creed_is_dead
   〰〰〰〰〰〰〰〰
   ߔࠀ   our admins are : 
   ߔࠀ   @sorblack_creed
   ߔࠀ   @amircc_creed
   ߔࠀ   @aria_creed
   〰〰〰〰〰〰〰〰
  ♻️ You can send your Ideas and messages to Us By sending them into bots account by this command :
   تمامی درخواست ها و همه ی انتقادات و حرفاتونو با دستور زیر بفرستین به ما
   !feedback (your ideas and messages)
]],
    help_text_realm = [[
➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖

⛔️برای ادمین ها : 

➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖➖




🔰 صلب مسدود از همه :

🔹 برای دراوردن شخص از حالت مسدودیت از همه ی گروه ها .
------------------------------------------------------------------------------------------------------------
🔰 لیست مسدود از همه :

🔹 برای دیدن افرادی که از همه ی گروه های ربات مسدود هستند
------------------------------------------------------------------------------------------------------------
🔰  خواندن (روشن/خاموش) : 

🔹  برای تیک خوردن پیاماتون توی گروه با خواندن ربات و برعکس . 
------------------------------------------------------------------------------------------------------------
🔰  لیست مکالمه : 

🔹  برای  دیدن آخرین پیام هر کس در گروه و گرفتن لیست مکالمه ها در گروه استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  حذف مخاطب : 

🔹  برای حذف کردن مخاطب از مخاطبان ربات استفاده میشود.
------------------------------------------------------------------------------------------------------------
🔰  تنظیم عکس ربات : 

🔹  برای تغییر عکس ربات استفاده میشود ( فقط عکس قبلی سرجاش میمونه)
------------------------------------------------------------------------------------------------------------
🔰  مخاطبان : 

🔹  لیست مخاطبان ربات را ارسال میکند .
------------------------------------------------------------------------------------------------------------
🔰  پیام به (ای دی) (پیام) : 

🔹  ارسال پیام مورد نظر شما به شخصی توطی ای دیش
------------------------------------------------------------------------------------------------------------
🔰  (بلاک/آنبلاک) (ای دی) : 

🔹  برای (بلاک/آنبلاک) کردن شخصی استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  کیست (ای دی ) :

🔹  مالک ای دی داده شده را خواهد داد
------------------------------------------------------------------------------------------------------------
🔰  ساخت ریلم/گروه ( اسم گروه /ریلم) :

🔹  برای ساختن گروه یا ریلم با اسم ساخته میشود .
------------------------------------------------------------------------------------------------------------
🔰  نصب [ اسم / قوانین / توضیحات] (ای دی گروه) (اسم گروه) : 

🔹  برای نصب [ اسم / قوانین / توضیحات]  گروهی که در آن نیستید از ریلم استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  (قفل/بازکردن) (ای دی گروه ) [ استیکر/اسم/ورود/عکس/اسپم/فارسی/تبلیغ/انگلیسی/فحش/تگ/خروج/ربات  ]

🔹  برای قفلکردن یا بازکردن تنظیمات یک گروه استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  تنظیمات (ای دی گروه) : 

🔹  برای مشاهده ی تنظیمات گروهی استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  حذف (گروه/ریلم) (ای دی گروه/ریلم) : 

🔹  برای حذف کردن اعضا و گروهی به کلی از گروه ریلم
------------------------------------------------------------------------------------------------------------
🔰  (نصب/صلب) ادمین : 

🔹  برای اضافه کردن ادمینی و یا صلب مقامش استفاده میشود 
------------------------------------------------------------------------------------------------------------
🔰  راهنما : 

🔹  لیست دستورات رو بهتون متناسب با گروه یا ریلم بودن میده
------------------------------------------------------------------------------------------------------------
🔰  لیست اعضا :

🔹  برای مشاهده ی لیست اعضاش گروه استفاده میشود 
------------------------------------------------------------------------------------------------------------
🔰  اعضا : 

🔹  برای دریافت فایل اعضای گروه استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  لیست (ریلم ها/گروه ها/ادمین ها) : 

🔹  برای دریافت لیست  (ریلم ها/گروه ها/ادمین ها)  استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  تاریخچه : 

🔹  برای دیدن تارخچه ی عملیات گروه استفاده میشود
------------------------------------------------------------------------------------------------------------
🔰  جوین (لینک) : 

🔹  برای جوین دادن به گروه یا کانال یا . توسط لینک 
------------------------------------------------------------------------------------------------------------
🔰  گروه ها : 

🔹  لیست گروه های ربات
------------------------------------------------------------------------------------------------------------
🔰  لیست گروه : 

🔹  ارسال گروه ها در فایل متنی . 
------------------------------------------------------------------------------------------------------------


کانال ما : @Pro_Programing

اعضای اصلی ما : 

@Arsalan_Sahel  [سازنده]
@Bad00boy_Creed [عضو اصلی ]
@Creed_aria [عضو اصلی]
@AmirCc_CreeD [عضو اصلی]
]],
    help_text = [[
⚜دستورات اداره‌ی گروه⚜
➖➖➖➖➖➖➖➖➖
🔰نصب مقام|صلب مقام :
🔹برای دادن یا گرفتن مقام به شخصی با ریپلای 
--------------------------------------
🔰اطلاعات (آی دی|نام کاربری|ریپلای):
🔹مشاهده اطلاعات شخص مورد نظر
--------------------------------------
🔰لیست مسدودان:
🔹مشاهده افراد مسدود شده از گروه
--------------------------------------
🔰مسدود|صلب مسدود (ای دی|نام کاربری):
🔹برای مسدود کردن یا دراوردن مسدود شخص مورد نظر از گروه
--------------------------------------
🔰اخراج (ای دی|نام کاربری|ریپلای):
🔹برای اخراج کردن فرد از گروه
--------------------------------------
🔰قوانین|تنظیم قوانین:
🔹دیدن قوانین یا تنظیم آن
--------------------------------------
🔰توضیحات|تنظیم توضیحات:
🔹دیدن توضیحات یا تنظیم آن
--------------------------------------
🔰نصب عکس|اسم:
🔹تعویض یا گذاشتن عکس یا اسم برای گروه
--------------------------------------
🔰ارتقا (ای دی|نام کاربری|ریپلای):
🔹 ارتقا دادن شخصی به عنوان کمک مدیر
--------------------------------------
🔰پاک کردن قوانین|لیست مدیران|توضیحات:
🔹پاک کردن گذینه های بالا
--------------------------------------
🔰حذف مدیر (ای دی|نام کاربری|ریپلای):
🔹 برای حذف کردن یک مدیر
--------------------------------------
🔰قفل|باز کردن: (همه|استیکر|اسم|ورود|عکس|اسپم|فارسی|تتبلیغ|انگلیسی|فحش|تگ|خروج|ربات)
🔹قفل یا باز کردن گذینه های بالا
--------------------------------------
🔰نصب مالک:
🔹برای دادن مقام مالکیت به یک فرد
--------------------------------------
🔰درمورد (نام کاربری):
🔹دیدن ای دی و اسم شخصی
--------------------------------------
🔰حساسیت (عدد):
🔹حساسیت ضد اسپم
--------------------------------------
🔰تنظیمات:
🔹مشاهده تنظیمات گروه
--------------------------------------
🔰لیست مدیران:
🔹لیست افراد مدیر در گروه
--------------------------------------
🔰لینک|لینک جدید:
🔹دریافت لینک یا ساخت لینک جدید
--------------------------------------
🔰ای دی (فقط با ریپلای):
🔹گرفتن ای دی شخصی
--------------------------------------
🔰اخراج غیر فعال:
🔹اخراج افراد غیر فعال
--------------------------------------
🔰اخراجم کن:
🔹خروج از گروه
--------------------------------------
👷سازنده: @anonymous1221
👮کانال ما: @bottgcha
--------------------------------------
نکته :
از طریق  !feedback یا ارسال نظر نظرات یا مشکلات را برای ما ارسال کنید
]],
  }
  serialize_to_file(config, './data/config.lua')
  print('saved config into ./data/config.lua')
end

function on_our_id (id)
  our_id = id
end

function on_user_update (user, what)
  --vardump (user)
end

function on_chat_update (chat, what)

end

function on_secret_chat_update (schat, what)
  --vardump (schat)
end

function on_get_difference_end ()
end

-- Enable plugins in config.json
function load_plugins()
  for k, v in pairs(_config.enabled_plugins) do
    print("Loading plugin", v)

    local ok, err =  pcall(function()
      local t = loadfile("plugins/"..v..'.lua')()
      plugins[v] = t
    end)

    if not ok then
      print('\27[31mError loading plugin '..v..'\27[39m')
      print('\27[31m'..err..'\27[39m')
    end

  end
end


-- custom add
function load_data(filename)

	local f = io.open(filename)
	if not f then
		return {}
	end
	local s = f:read('*all')
	f:close()
	local data = JSON.decode(s)

	return data

end

function save_data(filename, data)

	local s = JSON.encode(data)
	local f = io.open(filename, 'w')
	f:write(s)
	f:close()

end

-- Call and postpone execution for cron plugins
function cron_plugins()

  for name, plugin in pairs(plugins) do
    -- Only plugins with cron function
    if plugin.cron ~= nil then
      plugin.cron()
    end
  end

  -- Called again in 2 mins
  postpone (cron_plugins, false, 120)
end

-- Start and load values
our_id = 0
now = os.time()
math.randomseed(now)
started = false
