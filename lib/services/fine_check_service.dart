import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

Future<bool> checkForFine({
  required String plateNumber,
}) async {
  final client = http.Client();
  try {
    final url = Uri.parse('https://www.fsm.gov.mo/webticket/Webform1.aspx?carClass=L&Lang=C');

    // Step 1: GET 查詢頁，取得 __VIEWSTATE 等參數與 Cookie
    final getResp = await client.get(url, headers: {
      'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:114.0) Gecko/20100101 Firefox/114.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
    });

    if (getResp.statusCode != 200) {
      print('🔴 無法載入查詢頁面，HTTP ${getResp.statusCode}');
      return false;
    }

    final document = parse(getResp.body);
    String? getInputValue(String name) =>
        document.querySelector('input[name="$name"]')?.attributes['value'];

    final viewState = getInputValue('__VIEWSTATE');
    final viewStateGen = getInputValue('__VIEWSTATEGENERATOR');
    final eventValidation = getInputValue('__EVENTVALIDATION');

    if (viewState == null || viewStateGen == null || eventValidation == null) {
      print('🔴 無法取得 VIEWSTATE 或 EVENTVALIDATION');
      return false;
    }

    // 從 GET 回應中取得 cookie
    final cookies = getResp.headers['set-cookie'];
    // 可能有多個 cookie，用分號或逗號分隔，這裡簡單取第一組
    final cookieHeader = cookies?.split(';').first ?? '';

    // Step 2: POST 模擬表單送出查詢 (帶上 Cookie)
    final postRequest = http.Request('POST', url)
      ..headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://www.fsm.gov.mo',
        'Referer': url.toString(),
        'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:114.0) Gecko/20100101 Firefox/114.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
        'Cookie': cookieHeader,
      })
      ..bodyFields = {
        '__VIEWSTATE': viewState,
        '__VIEWSTATEGENERATOR': viewStateGen,
        '__EVENTVALIDATION': eventValidation,
        '__EVENTTARGET': '',
        '__EVENTARGUMENT': '',
        'Calculator': plateNumber,
        'btnOk': '確\u3000定',  // 全形空格 U+3000
      };

    final streamedResp = await client.send(postRequest);
    var response = await http.Response.fromStream(streamedResp);

    print('✅ 寄出表單內容：');
    postRequest.bodyFields.forEach((k, v) => print('  $k = $v'));

    // 處理 302 重導向（若有）
    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        final redirectUrl = location.startsWith('http')
            ? location
            : 'https://www.fsm.gov.mo' + (location.startsWith('/') ? '' : '/') + location;
        print('🔄 已跳轉至：$redirectUrl');

        final redirectResp = await client.get(Uri.parse(redirectUrl), headers: {
          'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:114.0) Gecko/20100101 Firefox/114.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-TW,zh;q=0.9,en-US;q=0.8,en;q=0.7',
          'Referer': url.toString(),
          'Cookie': cookieHeader,
        });
        response = redirectResp;
      }
    }

    if (response.request?.url.path.endsWith('default.aspx') == true) {
      print('🔴 表單送出失敗，導回首頁(default.aspx)，可能是驗證錯誤');
      return false;
    }

    // Step 3: 判斷罰單內容
    final resultDoc = parse(response.body);
    final noTicketElement = resultDoc.querySelector('#lbNoTicket2');
    final text = noTicketElement?.text.trim();

    print('🟡 抓到 #lbNoTicket2：$noTicketElement');
    print('🟡 抓到內容：$text');

    if (text != null && text.contains('沒有違例紀錄')) {
      print('✅ 沒有罰單');
      return false;
    } else {
      print('❗ 最終確認：有罰單');
      return true;
    }
  } catch (e) {
    print('🔴 查詢罰單時發生錯誤: $e');
    return false;
  } finally {
    client.close();
  }
}