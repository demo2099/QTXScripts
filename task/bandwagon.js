
const $ = API("bandwagon", false); // API("APP") --> 无log输出

gitvalue();
function gitvalue(){
    if ($.read("veids") !== undefined && $.read("api_keys") !== undefined) {
        const veidarry = $.read("veids").toString().split(",");
        const api_keyarry = $.read("api_keys").toString().split(",");
        for(var i=0;i<veidarry.length;i++){
            check_flow(parseInt(veidarry[i]),api_keyarry[i]);
        }
    }else {
        console.log("no data")
    }
}
$.done();
// 格式化时间
function formatTime(date) {
    var Y = date.getFullYear() + '-';
    var M = (date.getMonth()+1 < 10 ? '0'+(date.getMonth()+1) : date.getMonth()+1) + '-';
    // var D = date.getDate() + ' ';
    var D = (date.getDate() < 10 ? '0'+date.getDate() : date.getDate()) + ' ';
    var h = date.getHours() + ':';
    var m = date.getMinutes() + ':';
    var s = date.getSeconds();
    return Y+M+D+h+m+s;
}

// 前一个月时间
function preMonthTime(resetTime) {
    var date = new Date(resetTime);
    date.setMonth(date.getMonth() - 1);
    return date;
}
// 当前月份天数
function monthDays(currentTime) {
    var date = new Date(currentTime)
    //将当前月份加1，下移到下一个月
    date.setMonth(date.getMonth()+1);
    date.setDate(0);
    return date.getDate();
}
// 计算当前时间 间隔
function intervalTimes(startTime, endTime) {
    var stime = Date.parse(startTime);
    var etime = Date.parse(endTime);
    // 两个时间戳相差的毫秒数
    var usedTime = etime - stime;
    // 计算相差的天数
    var days = Math.floor(usedTime / (24 * 3600 * 1000));
    // 计算天数后剩余的毫秒数
    var leave1 = usedTime % (24 * 3600 * 1000);
    // 计算出小时数
    var hours = Math.floor(leave1 / (3600 * 1000));
    // 计算小时数后剩余的毫秒数
    var leave2 = leave1 % (3600 * 1000);
    // 计算相差分钟数
    var minutes = Math.floor(leave2 / (60 * 1000));
    var time = days + "天" + hours + "时" + minutes + "分";
    return time;
}
// 剩余平均每天可用流量
function averageFlow(startTime, endTime, flow) {
    var stime = Date.parse(startTime);
    var etime = Date.parse(endTime);
    // 两个时间戳相差的毫秒数
    var usedTime = etime - stime;
    var dayFlow = flow / 1073741824 / usedTime * 1000 * 3600 * 24;
    return dayFlow.toFixed(3)
}


function parse_flow(data) {
    var currentTime = new Date();
    var resetTime = new Date(data.data_next_reset * 1000);
    var startTime = preMonthTime(resetTime);

    var use_plan = (data.data_counter/1073741824).toFixed(2) + "/" + data.plan_monthly_data/1073741824 + "G";
    var percent = (data.data_counter * 100 / data.plan_monthly_data).toFixed(2) + "%";
    var ip = data.ip_addresses[0];
    var reset_date = formatTime(resetTime);
    var start_date = formatTime(startTime);

    var days = monthDays(startTime);
    var residue = ((data.plan_monthly_data - data.data_counter)/1073741824).toFixed(2) + "G"

    var subTitle = "已用: "+ percent + ", " + use_plan + " 剩余: "+ residue;

    var usedTimes = intervalTimes(startTime, currentTime);
    var residueTimes = intervalTimes(currentTime, resetTime);

    var residueFlow = averageFlow(currentTime, resetTime, data.plan_monthly_data - data.data_counter);
    var usedFlow = averageFlow(startTime, currentTime, data.data_counter);

    var msg1 = "已用: " + usedTimes + ", 平均每天: " + usedFlow + "GB";
    var msg2 = "剩余: " + residueTimes + ", 剩余每天: " + residueFlow + "GB";
    var msg3 = "本月: " + days + "天, 重置: " + reset_date;
    var message = msg1 + "\n" + msg2 + "\n" + msg3;

    $.notify("搬瓦工流量"+data.node_datacenter, subTitle, message);
    $.log(subTitle);
    $.log(message);
}

function check_flow(veid, apikey) {
    var request = {
        url: "https://api.64clouds.com/v1/getServiceInfo?veid=" + veid + "&api_key="+ apikey,
        headers: {
            "Content-Type": "application/x-www-form-urlencoded;charset=utf-8",
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 13_1_3 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 - mmbWebBrowse - ios"
        }
    };

    $.get(request)
        .then((resp) => {
            const body = resp.body;
            parse_flow(JSON.parse(body));

        })
        .catch((err) => $.notify("搬瓦工流量查询！", "接口查询错误", JSON.stringify(err)));
}

// prettier-ignore
/*********************************** API *************************************/
function API(t = "untitled", s = !1) { return new class { constructor(t, s) { this.name = t, this.debug = s, this.isQX = "undefined" != typeof $task, this.isLoon = "undefined" != typeof $loon, this.isSurge = "undefined" != typeof $httpClient && !this.isLoon, this.isNode = "function" == typeof require, this.isJSBox = this.isNode && "undefined" != typeof $jsbox, this.node = (() => this.isNode ? { request: "undefined" != typeof $request ? void 0 : require("request"), fs: require("fs") } : null)(), this.cache = this.initCache(), this.log(`INITIAL CACHE:\n${JSON.stringify(this.cache)}`), Promise.prototype.delay = function (t) { return this.then(function (s) { return ((t, s) => new Promise(function (e) { setTimeout(e.bind(null, s), t) }))(t, s) }) } } get(t) { return this.isQX ? ("string" == typeof t && (t = { url: t, method: "GET" }), $task.fetch(t)) : new Promise((s, e) => { this.isLoon || this.isSurge ? $httpClient.get(t, (t, i, o) => { t ? e(t) : s({ status: i.status, headers: i.headers, body: o }) }) : this.node.request(t, (t, i, o) => { t ? e(t) : s({ ...i, status: i.statusCode, body: o }) }) }) } post(t) { return this.isQX ? ("string" == typeof t && (t = { url: t }), t.method = "POST", $task.fetch(t)) : new Promise((s, e) => { this.isLoon || this.isSurge ? $httpClient.post(t, (t, i, o) => { t ? e(t) : s({ status: i.status, headers: i.headers, body: o }) }) : this.node.request.post(t, (t, i, o) => { t ? e(t) : s({ ...i, status: i.statusCode, body: o }) }) }) } initCache() { if (this.isQX) return JSON.parse($prefs.valueForKey(this.name) || "{}"); if (this.isLoon || this.isSurge) return JSON.parse($persistentStore.read(this.name) || "{}"); if (this.isNode) { const t = `${this.name}.json`; return this.node.fs.existsSync(t) ? JSON.parse(this.node.fs.readFileSync(`${this.name}.json`)) : (this.node.fs.writeFileSync(t, JSON.stringify({}), { flag: "wx" }, t => console.log(t)), {}) } } persistCache() { const t = JSON.stringify(this.cache); this.log(`FLUSHING DATA:\n${t}`), this.isQX && $prefs.setValueForKey(t, this.name), (this.isLoon || this.isSurge) && $persistentStore.write(t, this.name), this.isNode && this.node.fs.writeFileSync(`${this.name}.json`, t, { flag: "w" }, t => console.log(t)) } write(t, s) { this.log(`SET ${s} = ${JSON.stringify(t)}`), this.cache[s] = t, this.persistCache() } read(t) { return this.log(`READ ${t} ==> ${JSON.stringify(this.cache[t])}`), this.cache[t] } delete(t) { this.log(`DELETE ${t}`), delete this.cache[t], this.persistCache() } notify(t, s, e, i) { const o = "string" == typeof i ? i : void 0, n = e + (null == o ? "" : `\n${o}`); this.isQX && (void 0 !== o ? $notify(t, s, e, { "open-url": o }) : $notify(t, s, e, i)), this.isSurge && $notification.post(t, s, n), this.isLoon && $notification.post(t, s, e), this.isNode && (this.isJSBox ? require("push").schedule({ title: t, body: s ? s + "\n" + e : e }) : console.log(`${t}\n${s}\n${n}\n\n`)) } log(t) { this.debug && console.log(t) } info(t) { console.log(t) } error(t) { console.log("ERROR: " + t) } wait(t) { return new Promise(s => setTimeout(s, t)) } done(t = {}) { this.isQX || this.isLoon || this.isSurge ? $done(t) : this.isNode && !this.isJSBox && "undefined" != typeof $context && ($context.headers = t.headers, $context.statusCode = t.statusCode, $context.body = t.body) } }(t, s) }
/*****************************************************************************/
