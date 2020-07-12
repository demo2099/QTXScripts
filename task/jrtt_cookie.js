/*
2020.7.9发布今日头条激素版签到脚本
公众号iosrule by红鲤鱼与绿鲤鱼与驴 2020.7.5
共计两个文件jrtt_cookie.js,jrtt_task.js
#今日头条签到获取ck loon
http-request https:\/\/i-lq\.snssdk\.com script-path=jrtt_cookie.js, requires-body=true, timeout=30, tag=今日头条激素CK
今日头条 = type=http-request,pattern=https:\/\/i-lq\.snssdk\.com,script-path=jrtt_cookie.js, requires-body=true
====================================
MITM=i-lq.snssdk.com
====================================
*/

//++++++++++++++++++++++++++++++++-
//1.需要申明的变量

const $iosrule = iosrule();//声明必须


//++++++++++++++++++++++++++++++++-

const jrttid="A";
const  jinritoutiao="今日头条激素版";

const jrtt_sleepurlckname="jrtt_sleepurlckname"+jrttid;
const jrtt_sleepckname="jrtt_sleepckname"+jrttid;

const jrtt_sleepbdname="jrtt_sleepbdname"+jrttid;







//++++++++++++++++++++++++++++++++-


if ($iosrule.isRequest)
{


jrtt_writeck();
  
  }
$iosrule.end()
  
  
function jrtt_writeck() {

if ($request.headers) {

 var urlval = $request.url;

var md_header=$request.headers;
var md_bd=$request.body;

var tt=jinritoutiao;


if(urlval.indexOf("score_task/v1/sleep/done_task")>=0)
{
 
var jrtt_sleepurlck=urlval.substring(urlval.indexOf("done_task/")+10,urlval.length);

var jrtthok1= $iosrule.write(jrtt_sleepurlck,jrtt_sleepurlckname);
 var jrtthok2= $iosrule.write(md_header["x-Tt-Token"],jrtt_sleepckname);

console.log()
 var jrtthok3= $iosrule.write(md_bd,jrtt_sleepbdname);


if (jrtthok1==true&&jrtthok2==true&&jrtthok3==true) 
 papa(tt,"[睡觉💤ck]","写入" + tt + "睡觉数据成功");}




}
}































//可以增加模块



function papa(x,y,z){
 $iosrule.notify(x,y,z);}




function iosrule() {
    const isRequest = typeof $request != "undefined"
    const isSurge = typeof $httpClient != "undefined"
    const isQuanX = typeof $task != "undefined"
    const notify = (title, subtitle, message) => {
        if (isQuanX) $notify(title, subtitle, message)
        if (isSurge) $notification.post(title, subtitle, message)
    }
    const write = (value, key) => {
        if (isQuanX) return $prefs.setValueForKey(value, key)
        if (isSurge) return $persistentStore.write(value, key)
    }
    const read = (key) => {
        if (isQuanX) return $prefs.valueForKey(key)
        if (isSurge) return $persistentStore.read(key)
    }
    const get = (options, callback) => {
        if (isQuanX) {
            if (typeof options == "string") options = { url: options }
            options["method"] = "GET"
            $task.fetch(options).then(response => {
                response["status"] = response.statusCode
                callback(null, response, response.body)
            }, reason => callback(reason.error, null, null))
        }
        if (isSurge) $httpClient.get(options, callback)
    }
    const post = (options, callback) => {
        if (isQuanX) {
            if (typeof options == "string") options = { url: options }
            options["method"] = "POST"
            $task.fetch(options).then(response => {
                response["status"] = response.statusCode
                callback(null, response, response.body)
            }, reason => callback(reason.error, null, null))
        }
        if (isSurge) $httpClient.post(options, callback)
    }
    const end = () => {
        if (isQuanX) isRequest ? $done({}) : ""
        if (isSurge) isRequest ? $done({}) : $done()
    }
    return { isRequest, isQuanX, isSurge, notify, write, read, get, post, end }
};
