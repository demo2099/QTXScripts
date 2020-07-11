/*
腾讯新闻签到修改版，可以自动阅读文章获取红包，该活动为瓜分百万阅读红包挑战赛，针对幸运用户参与

此脚本默认关闭无红包通知阅读通知，如需全部开启请修改下面设置

获取Cookie方法:
1. 把以下地址复制到响应配置下，非Quantumult X 1.0.8+ tf版，请删除tag标签
2.打开腾讯新闻app，阅读几篇文章，倒计时结束后即可获取阅读Cookie;
3.获取红包ID的Cookie方法，点击红包倒计时，或者点击活动页面的专属红包任务，有些账号可能无，或者打开链接，可能激活阅读红包，链接地址:https://news.qq.com/FERD/cjRedDown.htm
4.现阶段每日共9个阶梯红包，具体阅读篇数视腾讯情况而变动
5.脚本运行一次阅读一篇文章，请不要连续运行，防止封号，可设置每几分钟运行一次
6.可能腾讯有某些限制，有些号码无法领取红包，手动阅读几篇，能领取红包，一般情况下都是正常的
7.4月27日修复该账户为非活动用户

----------------------------
Surge 4.0
[Script]
腾讯新闻 = type=cron,cronexp=0 8 0 * * *,script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js,script-update-interval=0

腾讯新闻 = type=http-request,pattern=https:\/\/api\.inews\.qq\.com\/event\/v1\/user\/event\/report\?,script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js
腾讯新闻 = type=http-request,pattern=^https:\/\/api\.inews\.qq\.com\/activity\/v1\/redpack\/user\/list\?activity_id,script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js

~~~~~~~~~~~~~~~~~~~~~
Loon 2.1.0+
[Script]
# 本地脚本
cron "04 00 * * *" script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js, enabled=true, tag=腾讯新闻

http-request https:\/\/api\.inews\.qq\.com\/event\/v1\/user\/event\/report\? script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js

http-request ^https:\/\/api\.inews\.qq\.com\/activity\/v1\/redpack\/user\/list\?activity_id script-path=https://raw.githubusercontent.com/Sunert/Scripts/master/Task/txnews2.js

-----------------
#  QX 1.0.7+
 [task_local]
0 9 * * * txnews2.js, tag=腾讯新闻
 [rewrite_local]
https:\/\/api\.inews\.qq\.com\/event\/v1\/user\/event\/report\? url script-request-header txnews2.js
# 获取红包ID
^https:\/\/api\.inews\.qq\.com\/activity\/v1\/redpack\/user\/list\?activity_id url script-request-header txnews2.js

~~~~~~~~~~~~~~~~~~
 [MITM]
hostname = api.inews.qq.com

~~~~~~~~~~~~~~~~
Cookie获取后，请注释掉Cookie地址。

#腾讯新闻app签到，根据红鲤鱼与绿鲤鱼与驴修改

*/
const notify = true; //开启全部通知为true，关闭继续阅读为false
const cookieName = '腾讯新闻ZIYE'
const signurlKey = 'sy_signurl_txnew17'
const cookieKey = 'sy_cookie_txnew17'
const RedIDKey = 'sy_rd_txnew17'
const sy = init()
const signurlVal = sy.getdata(signurlKey)
const cookieVal = sy.getdata(cookieKey)
const RedID = sy.getdata(RedIDKey)

let isGetCookie = typeof $request !== 'undefined'
if (isGetCookie) {
   GetCookie()
} else {
   getsign()
}

function GetCookie() {
if ($request && $request.method != 'OPTIONS' && $request.url.match(/user\/event\/report\?/)) {
  const signurlVal =  $request.url
  const cookieVal = $request.headers['Cookie'];
  sy.log(`signurlVal:${signurlVal}`)
  sy.log(`cookieVal:${cookieVal}`)
  if (signurlVal) sy.setdata(signurlVal, signurlKey)
  if (cookieVal) sy.setdata(cookieVal, cookieKey)
  sy.msg(cookieName, `获取Cookie: 成功🎉`, ``)
  }

if ($request && $request.method != 'OPTIONS'&& $request.url.match(/redpack\/user\/list\?activity/)) {
  const RedID =  $request.url.split("=")[1].split("&")[0]
  if (RedID) sy.setdata(RedID, RedIDKey)
  sy.msg(cookieName, `获取红包ID: 成功🎉`, ``)
  }
 }

//签到
function getsign() {
return new Promise((resolve, reject) => {
  const llUrl = {
    url: `https://api.inews.qq.com/task/v1/user/signin/add?`,headers:{Cookie: cookieVal}
  };
   sy.post(llUrl, (error, response, data) => {   
     sy.log(`${cookieName}签到 - data: ${data}`)
      const obj = JSON.parse(data)
      if (obj.info=="success"){
      //sy.log('腾讯新闻 签到成功，已连续签到' + obj.data.signin_days+"天"+"\n")
       next = obj.data.next_points
       tip =  obj.data.tip_soup
       Dictum = tip.replace(/[\<|\.|\>|br]/g,"")+obj.data.author
       str =  '签到成功'
       toRead()} 
      else {
        sy.msg('签到失败，🉐登录腾讯新闻app获取cookie', "", "")
        console.log('签到失败，🉐登录腾讯新闻app获取cookie'+data)
       }
    resolve()
    })
  })
}

//阅读阶梯
function toRead() {
  const toreadUrl = {
    url: signurlVal,
    headers: {Cookie:cookieVal},
    body: 'event=article_read&extend={"article_id":"20200424A08KNH00","channel_id":"17240460"}'
  };
   sy.post(toreadUrl,(error, response, data) =>{
      if (error){
      sy.msg(cookieName, '阅读:'+ error)
        }else{
       //sy.log(`${cookieName}阅读文章 - data: ${data}`)
      }
    redidCheck()
    })
  }

function redidCheck() {
   if(RedID !=null|undefined){
      StepsTotal()
    }else {
      sy.msg(cookieName,str,"获取红包ID失败❌，请检查是否获取红包Cookie或者该用户为非活动用户")
  }
}

//阅读文章统计
function StepsTotal() {
   const ID =  signurlVal.match(/devid=[a-zA-Z0-9_-]+/g)
  const StepsUrl = {
    url: `https://api.inews.qq.com/activity/v1/activity/info/get?activity_id=${RedID}&${ID}`,
   headers: {Cookie: cookieVal},
  }
    sy.get(StepsUrl, (error, response, data) => {
      try {
        sy.log(`${cookieName}阅读统计 - data: ${data}`)
        article = JSON.parse(data)
        if (article.ret == 0){
        redpacktotal =  article.data.extends.redpack_total
         redpackgot = article.data.extends.redpack_got
           haveread = article.data.extends.article.have_read_num
         getreadpack = article.data.extends.article.redpack_read_num
        if (redpackgot < redpacktotal-1){
         articletotal = '\n今日共'+redpacktotal+'个红包，' 
+'已领取'+redpackgot+'个，'+`已阅读`+ haveread+`篇文章，`+ `阅读至`+getreadpack+'篇，可领取红包' }
      if (redpackgot == redpacktotal-1){
         articletotal = '\n今日共'+redpacktotal+'个红包，' +'已领取'+redpackgot+'个，'+`已阅读`+ haveread+`篇文章，`+ `阅读至`+getreadpack+'篇，可领取今日最后一次红包' }
      if (redpackgot == redpacktotal){
       articletotal = `\n今日已阅读` + getreadpack+ `篇，`+ `共领取`+  redpackgot +`个阶梯红包`
     }
        str += articletotal + `\n`+ Dictum
        }
        else if (article.ret == 2011){
         str += `\n`+ Dictum
        }
        else {
     sy.log(cookieName + ` 返回值: ${article.ret}, 返回信息: ${article.info}`) 
        }
       getTotal()
       }
      catch (e) {
      sy.msg(cookieName, "",'阅读统计:失败'+ e)
     }
  })
}
//阶梯红包到账
function Redpack() {
  const ID =  signurlVal.match(/devid=[a-zA-Z0-9_-]+/g)
  const cashUrl = {
    url: `https://api.inews.qq.com/activity/v1/activity/redpack/get?isJailbreak=0&${ID}`,
      headers: {Cookie: cookieVal},
      body: `activity_id=${RedID}`
  };
    sy.post(cashUrl, (error, response, data) => {
      try {
        sy.log(`${cookieName}阶梯红包提取 - data: ${data}`)
        rcash = JSON.parse(data)
        if (rcash.ret == 0){
            notb += `  阶梯红包到账: `+ rcash.data.redpack.amount/100 +`元 🌷`
           sy.msg(cookieName, notb, str)
           sy.log(cookieName+` `+notb+`\n`+ str)
            }
        else if (rcash.ret == 2013){
            if (article.data.extends.redpack_got<article.data.extends.redpack_total){
           notb += " "
         if (notify){
           sy.msg(cookieName, notb, str)
           sy.log(cookieName+` `+notb+`\n`+ str)
                 }
               }
          else { 
            notb += " 今日阶梯红包已领完 💤"
            sy.msg(cookieName, notb, str)
            sy.log(cookieName+` `+notb+`\n`+ str)
               }
             }
        else {
            notb +=  " "+rcash.info+"❌"
            sy.msg(cookieName, notb, str)
             }
       }
      catch (e) {
      sy.log(`❌ ${cookieName} read - 阅读奖励: ${e}`)
     }
  })
}

//收益总计
function getTotal() {
 return new Promise((resolve, reject) => {
  const totalUrl = {
    url: `https://api.inews.qq.com/activity/v1/usercenter/activity/list?isJailbreak`,
    headers: {Cookie: cookieVal}};
    sy.post(totalUrl, function(error,response, data) {
    if (error) {
        sy.msg("获取收益信息失败‼️", "", error);
     if (log) console.log("获取收益信息" + data)
    } else {
         const obj = JSON.parse(data)
           notb = '总计:'+obj.data.wealth[0].title +'金币  '+"红包" + obj.data.wealth[1].title+'元'
          Redpack()
          sy.log(cookieName+","+notb+ "\n" )
        }
      resolve()
      })
   })
 }

function init() {
    isSurge = () => {
      return undefined === this.$httpClient ? false : true
    }
    isQuanX = () => {
      return undefined === this.$task ? false : true
    }
    getdata = (key) => {
      if (isSurge()) return $persistentStore.read(key)
      if (isQuanX()) return $prefs.valueForKey(key)
    }
    setdata = (key, val) => {
      if (isSurge()) return $persistentStore.write(key, val)
      if (isQuanX()) return $prefs.setValueForKey(key, val)
    }
    msg = (title, subtitle, body) => {
      if (isSurge()) $notification.post(title, subtitle, body)
      if (isQuanX()) $notify(title, subtitle, body)
    }
    log = (message) => console.log(message)
    get = (url, cb) => {
      if (isSurge()) {
        $httpClient.get(url, cb)
      }
      if (isQuanX()) {
        url.method = 'GET'
        $task.fetch(url).then((resp) => cb(null, {}, resp.body))
      }
    }
    post = (url, cb) => {
      if (isSurge()) {
        $httpClient.post(url, cb)
      }
      if (isQuanX()) {
        url.method = 'POST'
        $task.fetch(url).then((resp) => cb(null, {}, resp.body))
      }
    }
    done = (value = {}) => {
      $done(value)
    }
    return { isSurge, isQuanX, msg, log, getdata, setdata, get, post, done }
  }
