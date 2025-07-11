import 'package:http/http.dart' as http;
import 'package:html/parser.dart' show parse;

/// 查詢罰單，根據 plateNumber 與車種（汽車 = 'L', 機車 = 'C'）
/// 回傳 true = 有罰單, false = 無罰單, null = 查詢錯誤 (車牌錯誤或未跳轉)
Future<bool?> checkForFine({
  required String plateNumber,
  required String vehicleType, // 'L' 或 'C'
}) async {
  final client = http.Client();

  try {
    final url = Uri.parse('https://www.fsm.gov.mo/webticket/Webform1.aspx?carClass=$vehicleType&Lang=C');

    // Step 1: 取得查詢頁 HTML 與 Cookie
    final getResp = await client.get(url, headers: {
      'User-Agent': 'Mozilla/5.0',
      'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
      'Accept-Language': 'zh-TW,zh;q=0.9',
    });

    if (getResp.statusCode != 200) {
      print('🔴 無法載入查詢頁面，HTTP ${getResp.statusCode}');
      return null;
    }

    final document = parse(getResp.body);
    String? getInputValue(String name) =>
        document.querySelector('input[name="$name"]')?.attributes['value'];

    final viewState = getInputValue('__VIEWSTATE');
    final viewStateGen = getInputValue('__VIEWSTATEGENERATOR');
    final eventValidation = getInputValue('__EVENTVALIDATION');

    if (viewState == null || viewStateGen == null || eventValidation == null) {
      print('🔴 無法取得 VIEWSTATE 或 EVENTVALIDATION');
      return null;
    }

    final cookies = getResp.headers['set-cookie'];
    final cookieHeader = cookies?.split(';').first ?? '';

    // Step 2: 模擬送出表單
    final postRequest = http.Request('POST', url)
      ..headers.addAll({
        'Content-Type': 'application/x-www-form-urlencoded',
        'Origin': 'https://www.fsm.gov.mo',
        'Referer': url.toString(),
        'User-Agent': 'Mozilla/5.0',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
        'Accept-Language': 'zh-TW,zh;q=0.9',
        'Cookie': cookieHeader,
      })
      ..bodyFields = {
        '__VIEWSTATE': viewState,
        '__VIEWSTATEGENERATOR': viewStateGen,
        '__EVENTVALIDATION': eventValidation,
        '__EVENTTARGET': '',
        '__EVENTARGUMENT': '',
        'Calculator': plateNumber,
        'btnOk': '確　定',
      };

    final streamedResp = await client.send(postRequest);
    var response = await http.Response.fromStream(streamedResp);

    print('✅ 寄出表單內容：');
    postRequest.bodyFields.forEach((k, v) => print('  $k = $v'));

    // Step 2.5: 可能的 302 跳轉
    if (response.statusCode == 302) {
      final location = response.headers['location'];
      if (location != null) {
        final redirectUrl = location.startsWith('http')
            ? location
            : 'https://www.fsm.gov.mo${location.startsWith('/') ? '' : '/'}$location';
        print('🔄 已跳轉至：$redirectUrl');

        response = await client.get(Uri.parse(redirectUrl), headers: {
          'User-Agent': 'Mozilla/5.0',
          'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/webp,*/*;q=0.8',
          'Accept-Language': 'zh-TW,zh;q=0.9',
          'Referer': url.toString(),
          'Cookie': cookieHeader,
        });
      }
    }

    // Step 2.6: 檢查是否跳轉到 WebForm7.aspx，否則可能是車牌無效
    final finalPath = response.request?.url.path ?? '';
    if (!finalPath.contains('WebForm7.aspx')) {
      print('🟥 查詢未跳轉到 WebForm7.aspx，可能車牌輸入錯誤或未登記');
      return null;
    }

    // Step 3: 分析結果頁面
    final resultDoc = parse(response.body);

    final noTicketElement = resultDoc.querySelector('#lbNoTicket2');
    final text = noTicketElement?.text.trim();

    print('🟡 抓到 #lbNoTicket2：$noTicketElement');
    print('🟡 抓到內容：$text');

    if (text != null && text.contains('沒有違例紀錄')) {
      print('✅ 沒有罰單');
      return false;
    }

    // 若沒有上述訊息，判為有罰單
    print('❗ 最終確認：有罰單');
    return true;

  } catch (e) {
    print('🔴 查詢罰單時發生例外錯誤: $e');
    return null;
  } finally {
    client.close();
  }
}
