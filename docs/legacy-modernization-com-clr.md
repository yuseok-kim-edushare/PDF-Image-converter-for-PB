---
marp: true
theme: gaia
size: 16:9
paginate: true
header: "레거시 현대화: .NET Framework COM + SQL CLR"
footer: "© 2025 yuseok.kim@edushare.kr"
---

<style>
  section { font-size: 22px; }
  h1 { color: #2563eb; text-shadow: 2px 2px 5px rgba(0,0,0,0.1); font-size: 40px; }
  h2 { color: #1e40af; font-size: 32px; }
  h3 { font-size: 24px; }
  p, li { font-size: 20px; line-height: 1.4; }
  pre, code { font-size: 18px; line-height: 1.3; }
  .highlight { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 15px; border-radius: 10px; font-size: 20px; }
  .workflow-box { background: #f3f4f6; border-left: 4px solid #3b82f6; padding: 12px; margin: 8px 0; font-size: 18px; }
  .columns { display: grid; grid-template-columns: 1fr 1fr; gap: 24px; }
</style>

# 🚀 레거시 앱 현대화: .NET Framework COM + SQL Server CLR

현대적 기능(TLS/암호화/확장기능)을 레거시 앱에 안전하게 이식하기

---

## 📋 아젠다

- 배경: 왜 COM/CLR 인가
- .NET Framework COM 오브젝트로 확장하기
- SQL Server CLR Assembly로 DB 내부 확장하기
- Interop 리소스/메모리 관리 주의사항
- 배포 체크리스트와 베스트 프랙티스
- 참고 자료

---

## 🧭 배경과 목표

<div class="columns">
  <div>
    <h3>레거시의 제약</h3>
    <ul>
      <li>최신 TLS/암호화 미지원</li>
      <li>이미지/PDF 처리 같은 현대 기능 부재</li>
      <li>외부 라이브러리 연계 어려움</li>
    </ul>
  </div>
  <div>
    <h3>현대화 목표</h3>
    <ul>
      <li>COM 오브젝트로 앱 외연 확장</li>
      <li>SQL CLR로 DB 내부 연산 강화</li>
      <li>안전한 배포와 유지보수 체계화</li>
    </ul>
  </div>
</div>

---

## 🔌 전략 개요

<div class="highlight">
<h3>두 축의 확장</h3>
<ul>
  <li>애플리케이션 경계 밖: .NET Framework COM 오브젝트</li>
  <li>데이터베이스 내부: SQL Server CLR Assembly</li>
</ul>
</div>

---

## 🧱 .NET Framework COM: 개념과 장점

- **레거시 앱에서 OLE/COM 인터페이스로 .NET 기능 호출**
- 최신 암호화, PDF/이미지, 네트워킹 기능을 **추가 설치 없이 재사용**
- PowerBuilder, VB6 등과의 **상호운용성 유지**
- **넓은 오픈소스 배경**으로 다양한 기능을 쉽게 도입 가능
- Microsoft가 관리하는 **OS에 통합된 기본 Framework** 기능의 탄탄함

---

## 🔧 COM 구현: 핵심 포인트

- Target: **.NET Framework 4.8.1** (보안패치 지원중인 windows target)
- `AssemblyInfo` / 특성: `ComVisible(true)`, 고정 `Guid`
- 인터페이스: `InterfaceIsDual` + 클래스: `ClassInterface.None`
- 배포: `RegAsm.exe Your.dll /codebase /tlb:Your.tlb`
- 32/64bit 일치, Strong Name 서명 권장

```csharp
using System;
using System.Runtime.InteropServices;

[Guid("00000000-0000-0000-0000-000000000001")]
[InterfaceType(ComInterfaceType.InterfaceIsDual)]
public interface ISecureLibrary
{
    string ComputeBcrypt(string password, int workFactor);
    byte[] EncryptAesGcm(byte[] key, byte[] plaintext, byte[] nonce, out byte[] tag);
}

[ComVisible(true)]
[Guid("00000000-0000-0000-0000-000000000002")]
[ClassInterface(ClassInterfaceType.None)]
public class SecureLibrary : ISecureLibrary { /* ... */ }
```

---

## 🔐 COM 사례: 암호화/TLS/키교환

**simple-.NET-Crypting-For-PB** 예시

- AES-GCM, Bcrypt PW hash, ECDH 키교환 구현
- PB/SQL Server 겸용 타깃 구성과 배포 자동화 가능
- 참고: `simple-.net-Crypting-For-PowerBuilder`

링크: [GitHub 저장소](https://github.com/yuseok-kim-edushare/simple-.net-Crypting-For-PowerBuilder)

---

## 🖼️ COM 사례: PDF → 이미지 변환

**PDF-Image-converter-for-PB** 예시

- PDF를 원본 크기 유지하며 PNG로 변환
- PowerBuilder에서 OLEObject로 호출

링크: [GitHub 저장소](https://github.com/yuseok-kim-edushare/PDF-Image-converter-for-PB)

---

## 🌐 COM 사례: FTP 유틸리티, 이미지 변환

- **FTP-For-Powerbuilder**: 레거시 환경에서 간단한 업/다운로드 유틸리티로 활용
  - 링크: [GitHub 저장소](https://github.com/yuseok-kim-edushare/FTP-For-Powerbuilder)
- **MS-SQL_IMG2JPG**: 이미지 포맷 변환 관련 도구로 통합 가능
  - 링크: [GitHub 저장소](https://github.com/yuseok-kim-edushare/MS-SQL_IMG2JPG)

---

## 🔗 PowerBuilder 인터페이스 예시

```powerbuilder
OLEObject ole
integer rc
string ls_hash

ole = CREATE OLEObject
rc = ole.ConnectToNewObject("SecureLibrary.SecureLibrary")
IF rc = 0 THEN
  ls_hash = ole.ComputeBcrypt("P@ssw0rd", 12)
  MessageBox("Bcrypt", ls_hash)
END IF

DESTROY ole
```

주의: 32/64bit 일치, 예외 처리와 객체 수명 주기 관리 필수

---

## 🧩 SQL Server CLR: 개념과 장점

- T-SQL로 힘든 연산을 **.NET 코드로 DB 내부에서 실행**
- 해시/암복호/포맷 변환/검증 로직 등
- 확장 시 보안/권한/성능 고려 필요

참고: [CLR 사례(발표자 블로그)](https://blog.naver.com/yuseok9808/223957708617)

---

## 🏗️ SQL CLR 함수 스켈레톤

```csharp
using Microsoft.SqlServer.Server;
using System.Data.SqlTypes;

public static class CryptoFunctions
{
    [SqlFunction(IsDeterministic = false, IsPrecise = true)]
    public static SqlString BcryptHash(SqlString input, SqlInt32 workFactor)
    {
        // BCrypt.Net.BCrypt.HashPassword(...)
        return new SqlString("...");
    }
}
```

```sql
-- 배포 예시
CREATE ASSEMBLY SecureLibrarySQL FROM 'C:\\path\\SecureLibrary-SQL.dll' WITH PERMISSION_SET = SAFE;
GO
CREATE FUNCTION dbo.BcryptHash(@input NVARCHAR(4000), @workFactor INT)
RETURNS NVARCHAR(4000)
AS EXTERNAL NAME [SecureLibrarySQL].[CryptoFunctions].[BcryptHash];
```

---

## 🛡️ CLR 보안/설정 체크

- `sp_configure 'clr enabled', 1; RECONFIGURE;`
- 가능하면 `SAFE` 권한 사용, 불가 시 `EXTERNAL_ACCESS` 최소화
- 어셈블리 서명/권한, TRUSTWORTHY 지양(대안: 인증서/서명)

---

## ⚠️ Interop 리소스/메모리 관리 주의

<div class="workflow-box">
<strong>"적절한 dispose가 치명적일 수 있다"</strong> — 수명 주기/소유권을 오해한 조기 Dispose는 크래시나 교착을 유발
</div>

- 실제 사례: 조기 Dispose/해제 순서 문제로 첨부파일 관련 메일 송신 실패/예외 발생


베스트 프랙티스

- C#: `using`으로 **명확한 소유권** 부여, 반환 객체를 호출자가 소유하면 호출자가 Dispose
- COM: `Marshal.FinalReleaseComObject`로 **한 번만** 해제, 중복 해제 금지
- 콜백/스트림: 호출자에게 넘긴 리소스는 **즉시 Dispose 금지**
- PowerBuilder: `DESTROY` 시점 일관성 유지, 예외 발생 시 누수 점검
---

## ✉️ 실제 코드: TLS 메일 전송 (권장 패턴)

```csharp
using System.Net;
using System.Net.Mail;

public static void SendMail(/* smtpServer, smtpPort, useTls, from, to, subject, body, smtpUser, smtpPass */)
{
    // 핵심: MailMessage와 SmtpClient 모두 using으로 수명 관리
    ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

    using (var message = new MailMessage())
    {
        // message.From = new MailAddress(from);
        // message.To.Add(to);
        // message.Subject = subject;
        // message.Body = body; message.IsBodyHtml = true;
        // message.Attachments.Add(new Attachment(path));

        using (var client = new SmtpClient(smtpServer, smtpPort))
        {
            client.EnableSsl = useTls; // STARTTLS 사용 시 true
            client.Credentials = new NetworkCredential(smtpUser, smtpPass);
            client.Send(message);
        }
    }
}
```

---

## 🚫 지양 패턴(안티패턴)

```csharp
// 1) 사전 Dispose된 스트림을 첨부로 추가
using (var ms = new MemoryStream(bytes))
{
    var att = new Attachment(ms, "a.bin");
    message.Attachments.Add(att);
} // ms가 여기서 Dispose됨
client.Send(message); // ObjectDisposedException 위험
```

```csharp
// 2) Attachment를 수동 Dispose (이중 해제 위험)
var att = new Attachment(path);
message.Attachments.Add(att);
att.Dispose(); // MailMessage.Dispose()에서 다시 해제될 수 있음
```

```csharp
// 3) using 범위 밖에서 전송 (이미 Dispose된 객체 사용)
MailMessage message;
using (message = new MailMessage(/*...*/)) { }
client.Send(message); // ObjectDisposedException
```

<div class="workflow-box">
권장: 첨부는 메시지에만 연결하고, 전송 완료 후 <strong>메시지 하나만 Dispose</strong>로 정리합니다.
</div>

---

## 🔒 TLS/인증서 설정 팁 (.NET)

```csharp
// TLS 1.2 권장 (OS 정책 따름 / 보장만 된다면 Tls13으로 고정하는 게 좋음(현실적인 문제가...))
ServicePointManager.SecurityProtocol = SecurityProtocolType.Tls12;

// 인증서 검증은 기본값 유지가 원칙.
// 아래는 데모/테스트용으로만 사용(운영 비권장):
// 사설 인증서 필요시 인증서 키를 코드에 고정 혹은 환경변수로 관리 필요
ServicePointManager.ServerCertificateValidationCallback =
    (sender, cert, chain, errors) => errors == System.Net.Security.SslPolicyErrors.None;
```

---

## 📦 배포 체크리스트

- .NET Framework 4.8.1 런타임 배포
- COM 등록: `RegAsm Your.dll /codebase /tlb` (bitness 일치)
- Strong Name 서명, 버전 관리
- SQL CLR: 권한/서명/구성 반영, 함수/프로시저 외부 이름 정확도

---

## ✅ 베스트 프랙티스 요약

- 최소 권한 원칙: 기능 별로 좁은 인터페이스
- 호환성: 32/64bit, TLS 정책, CNG 사용 고려
- 관찰성: 로깅/진단 이벤트, 실패한 호출 재현 경로 확보
- 자동화: CI 테스트, 릴리스 아티팩트 일관성

---

## 🗺️ 점진적 도입 로드맵

1) 작은 COM 유틸리티부터 도입 (예: Bcrypt)
2) PDF/이미지 등 눈에 보이는 가치로 확장
3) 병목 로직을 SQL CLR로 이전
4) 모니터링/자동화/보안 정책 정착


---

## 🙋 Q&A

필요 시 데모/워크샵으로 심화 진행 가능합니다.

