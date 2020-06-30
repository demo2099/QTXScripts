/*

公众号iosrule by红鲤鱼与绿鲤鱼与驴
2020.6.27

#惠头条签到定时执行任务，建议1分钟以上频率
loon定时格式
cron "0 21,31,50 0-22 * * ?" script-path=htt_task.js, tag=惠头条
*/


//以上是配置说明
const $iosrule = iosrule();//声明必须



//====================================
const httid="A";
const huitoutiao="惠头条";


//++++++++++++++++++++++++++++++++-

const htt_videoname="htt_videoname"+httid;
const htt_video=$iosrule.read(htt_videoname);

const htt_dongfangname="htt_dongfangname"+httid;
const htt_dongfang=$iosrule.read(htt_dongfangname);

const htt_signurlckname="htt_signurlckname"+httid;
const htt_signurlck=$iosrule.read(htt_signurlckname);


const htt_signbdname="htt_signbdname"+httid;
const htt_signbd=$iosrule.read(htt_signbdname)
;



//++++++++++++++++++++++++++++++++













//++++++++++++++++++++++++++++++++

//3.需要执行的函数都写这里
function main()
{


htt_main();

  

}

function htt_main()
{


 htt_daysign();

  htt_hoursign();
htt_read_dongfang();
}



main()


//++++++++++++++++++++++++++++++++++++
//4.基础模板



function htt_daysign()
  {
   var result1="";var result2="";
var tt=huitoutiao;
const llUrl1 = {url:"https://api.cashtoutiao.com/frontend/sign?"+htt_signurlck,headers:{"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"},body:htt_signbd};var signjs=JSON.parse(htt_signbd);signjs["code"]=sign("%3Dhdfefni");const llUrl2 = {url:"https://api.cashtoutiao.com/frontend/invite?"+htt_signurlck,headers:{"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"},body:signjs};
 $iosrule.post(llUrl1, function(error, response, data) {
    var obj=JSON.parse(data)

   if(obj.statusCode==200)
{result2="[金币]"+obj.signCredit;
htt_signday(result2);}
else   if(obj.statusCode==-50)
{result2="[重复签到]";
htt_signday(result2);
   }
   })
    $iosrule.post(llUrl2, function(error, response, data){})
 }

function htt_hoursign()
  {
   var result1="[时段签到]";var result2="";
var tt=huitoutiao;
    const llUrl1 = {url:"https://api.cashtoutiao.com/frontend/credit/sych/reward/per/hour?"+htt_signurlck,headers:{"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"},body:htt_signbd};
 $iosrule.post(llUrl1, function(error, response, data) {
    var obj=JSON.parse(data);
   if(obj.statusCode==200)
result2="[金币]"+obj.credit;

else   if(obj.statusCode==-50)
result2=obj.msg;
   papa(tt,result1,result2);
   })
 }




function htt_signday(res)
  {
   var result1="";var result2="";
var tt=huitoutiao;
    const llUrl1 = {url:"https://api.cashtoutiao.com/frontend/sign/record?"+htt_signurlck,headers:{"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"},body:htt_signbd};

 $iosrule.post(llUrl1, function(error, response, data) {
    var obj=JSON.parse(data)

   if(obj.statusCode==200)
result2=res+"  [签到天数]"+obj.day;

   papa(tt,"[日签到]",result2);
   })
 }


function htt_read_dongfang()
  {
   var result1="阅读📖奖励";var result2="";
var tt=huitoutiao;
    const llUrl1 = {url:"https://api.cashtoutiao.com/frontend/read/sych/duration?"+htt_signurlck,headers:{"Content-Type":"application/json","User-Agent":"Mozilla/5.0 (iPhone; CPU iPhone OS 12_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148"},body:htt_dongfang};

 $iosrule.post(llUrl1, function(error, response, data) {
    var obj=JSON.parse(data)

   if(obj.statusCode==200)
   {if(data.indexOf("失败")<0)
{result2="[金币]"+obj.incCredit+"[ 今日总金币]"+obj.todayCredit+" [今日阅读时长]"+obj.todayDuration;}
else
{
  result2=obj.msg+",访问过快，请调整间隔30-60秒以上❌";result1="[阅读奖励失败]"
}

   papa(tt,result1,result2);}
   })
 }






















function papa(x,y,z){

 $iosrule.notify(x,y,z);}

function sign(code)  
{  
   code=unescape(code);  
   var c=String.fromCharCode(code.charCodeAt(0)-code.length);  
   for(var i=1;i<code.length;i++){  
       c+=String.fromCharCode(code.charCodeAt(i)-c.charCodeAt(i-1));  
   }  
   return c;  
}  



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





