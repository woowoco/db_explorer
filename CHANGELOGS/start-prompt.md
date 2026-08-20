# Proje: Extensible Cross-Platform Database Workbench + AI Query Assistant

Kendim kullanmak üzere, ileride Google Play Store, Windows, macOS, Linux, iOS ve diğer uygun platformlarda public olarak yayınlayabileceğim, **Flutter tabanlı cross-platform bir Database Management Workbench** geliştirmek istiyorum.

Uygulamanın ilk ve öncelikli database desteği **MongoDB** olacak. Ancak mimariyi kesinlikle yalnızca MongoDB'ye özel tasarlamak istemiyorum.

Uzun vadede PostgreSQL, MySQL, Redis, Elasticsearch ve diğer SQL/NoSQL/database sistemlerinin eklenebilmesine uygun, **extensible ve provider-based bir database architecture** oluşturmak istiyorum.

Ürünün en önemli farklılaştırıcı özelliği ise **AI Query Assistant** olacak.

---

# 1. ÇALIŞMA PRENSİBİ — ÖNCE ARAŞTIR, SONRA TASARLA

**Henüz kod yazmaya veya proje oluşturmaya başlama.**

İlk aşamada kapsamlı bir teknik araştırma yap ve bana uygulanabilir bir teknik tasarım önerisi sun.

Araştırma sonucunda:

* Ürün mimarisini
* Database provider mimarisini
* MongoDB bağlantı yöntemini
* Gelecekte farklı database'lerin nasıl eklenebileceğini
* Query abstraction yaklaşımını
* AI Query Assistant mimarisini
* Local AI seçeneklerini
* Flutter mimarisini
* Desktop / mobile UX yaklaşımını
* Security modelini
* Performans stratejisini
* MVP kapsamını
* Gelecek roadmap'ini
* Kullanılabilecek Flutter/native paketleri
* Teknik riskleri
* Alternatif teknolojileri

detaylı şekilde değerlendir.

**Araştırmadan varsayım yapma.**

Güncel framework, package, driver, local AI inference engine ve ilgili teknolojilerin mevcut durumlarını araştır.

Henüz implementation yapma.

---

# 2. MEVCUT PROJEMİ REFERANS AL

Mevcut Flutter projem:

`C:\Users\tolga.durak\Desktop\F_AISUBCRIBE\F_AISUBCRIBE_APP`

Bu projeyi yeni uygulamanın **tasarım dili ve uygun mimari yaklaşımları açısından referans** olarak incele.

Özellikle:

* Design system
* Color system
* Typography
* Spacing
* Border radius
* Buttons
* Inputs
* Dialogs
* Cards
* Navigation
* Responsive/adaptive UI
* Component architecture
* State management
* Folder structure
* Clean Architecture yaklaşımı
* Reusable widgets
* Naming conventions
* Genel kod organizasyonu

gibi konuları analiz et.

Yeni projede kendi kafana göre tamamen farklı bir design system oluşturma.

**Bana ait olan mevcut tasarım dilini koru ve geliştir.**

Ancak F_AISUBCRIBE projesindeki herhangi bir mimari veya teknik kararın yeni proje için uygun olmadığını düşünüyorsan bunu körü körüne kopyalama. Neden farklı bir yaklaşım önerdiğini açıkça belirt.

---

# 3. ÜRÜNÜN GERÇEK TANIMI

Bu uygulamayı yalnızca:

> "MongoDB GUI"

olarak düşünme.

Asıl ürün:

> **Extensible Cross-Platform Database Management Workbench + AI Query Assistant**

olacak.

MongoDB ilk database provider olacak.

Uzun vadede uygulamanın aşağıdaki gibi genişleyebilmesini istiyorum:

```text
Database Workbench
│
├── MongoDB
├── PostgreSQL
├── MySQL
├── Redis
├── Elasticsearch
├── SQLite
└── Future Providers
```

Ancak farklı database sistemlerini zorla aynı modele sokma.

**Relational, document, key-value, search engine vb. database paradigmalarının farklılıklarını mimaride koru.**

---

# 4. DATABASE PROVIDER ARCHITECTURE

Database bağlantısını doğrudan MongoDB'ye özel bir yapı olarak tasarlama.

Bunun yerine extensible bir provider architecture araştır.

Örneğin konsept olarak:

```text
DatabaseProvider
│
├── Connection
├── Metadata
├── Schema
├── Query
├── Data Explorer
├── Indexes
├── Statistics
└── Capabilities
```

gibi ortak yetenekler olabilir.

Ancak bunu körü körüne interface olarak uygulama.

Özellikle şunu araştır:

> MongoDB ve PostgreSQL gibi temelde farklı database sistemlerini ortak abstraction altında nasıl doğru şekilde modelleyebiliriz?

Örneğin:

```text
MongoDB
✓ Database
✓ Collection
✓ Document
✓ BSON
✓ Aggregation
✓ Index
✓ View

PostgreSQL
✓ Database
✓ Schema
✓ Table
✓ Row
✓ SQL
✓ Relation
✓ View
✓ Index
```

UI ve domain modelinin database'e özgü özellikleri kaybetmemesi gerekiyor.

Bu nedenle:

> **Common capabilities + provider-specific capabilities**

yaklaşımını değerlendir.

---

# 5. DATABASE CAPABILITY SYSTEM

Provider'ların desteklediği özellikleri dinamik olarak bildirebilmesini istiyorum.

Örneğin:

```text
MongoDB
- documents
- collections
- aggregation
- BSON
- indexes
- explain
- transactions

PostgreSQL
- tables
- rows
- SQL
- relations
- views
- indexes
- explain
- transactions
```

Böylece UI database'e göre kendisini adapte edebilsin.

Örneğin MongoDB bağlandığında:

```text
Collections
Documents
Indexes
Aggregation
```

görülebilirken PostgreSQL bağlandığında:

```text
Schemas
Tables
Views
Functions
Indexes
Relations
```

gibi farklı navigation gösterebilsin.

Bu capability-driven UI yaklaşımını araştır.

---

# 6. MONGODB — İLK PROVIDER

İlk implementasyon MongoDB olacak.

MongoDB için mümkün olduğunca kapsamlı destek hedefliyorum.

Araştır:

* Local MongoDB
* Remote MongoDB
* MongoDB Atlas
* Standalone
* Replica Set
* Connection String
* Username/password
* TLS/SSL
* Authentication yöntemleri
* MongoDB driver seçenekleri
* Dart MongoDB driver
* Native driver
* FFI
* C++
* Rust

Flutter ile MongoDB'ye doğrudan bağlanmanın avantaj/dezavantajlarını değerlendir.

Özellikle:

* Android
* iOS
* Windows
* macOS
* Linux

platformlarını ayrı değerlendir.

Gereksiz yere backend ekleme.

Mümkünse client'ın database'e doğrudan bağlanabilmesini istiyorum.

Ancak bunun güvenlik veya platform kısıtları nedeniyle uygun olmadığı durumlarda alternatifleri açıkça belirt.

---

# 7. CONNECTION MANAGER

Birden fazla database bağlantısı oluşturulabilmeli.

Örneğin:

```text
Connections

Production MongoDB
Development MongoDB
Local MongoDB
Production PostgreSQL
Local PostgreSQL
Redis Server
```

Connection profile içerisinde database provider'a göre gerekli alanlar dinamik olmalı.

Örneğin MongoDB:

```text
Connection Type: MongoDB
URI
Authentication
TLS
Options
```

PostgreSQL:

```text
Connection Type: PostgreSQL
Host
Port
Database
Username
Password
SSL
```

gibi.

**Connection formunun provider'a göre dinamik oluşturulmasını araştır.**

Credential'lar güvenli şekilde saklanmalı.

Windows/macOS/Linux/Android/iOS için uygun secure storage yöntemlerini araştır.

Password ve connection string'leri düz metin olarak saklama.

---

# 8. DATABASE EXPLORER

Bağlantı kurulduğunda database'e uygun explorer oluştur.

MongoDB örneği:

```text
Connection
└── Databases
    └── myDatabase
        ├── Collections
        │   ├── users
        │   ├── orders
        │   └── products
        ├── Views
        └── ...
```

PostgreSQL örneği:

```text
Connection
└── Databases
    └── production
        ├── Schemas
        │   └── public
        │       ├── Tables
        │       ├── Views
        │       ├── Functions
        │       └── ...
```

Explorer tamamen provider-aware olmalı.

---

# 9. DATA EXPLORER

Database içindeki verileri görüntülemek için güçlü bir data explorer oluştur.

MongoDB:

* Documents
* JSON
* Tree view
* Table/List view
* BSON types

SQL database:

* Rows
* Columns
* Tables
* Relations

gibi database modeline uygun UI oluştur.

Büyük dataset'lerde tüm veriyi memory'ye yükleme.

Araştır:

* Pagination
* Cursor based pagination
* Virtualized lists
* Virtualized tables
* Lazy loading
* Streaming

yaklaşımlarından hangilerinin uygun olduğunu belirle.

---

# 10. DATA EDITOR

Kullanıcı database türüne uygun olarak data üzerinde işlem yapabilmeli.

MongoDB:

* Insert document
* Update document
* Delete document

SQL:

* Insert row
* Update row
* Delete row

gibi.

Ancak bu işlemler:

> **AI tarafından otomatik olarak gerçekleştirilmeyecek.**

AI'ın database üzerinde write authority'si olmayacak.

Kullanıcı işlemi açıkça kendisi gerçekleştirecek.

---

# 11. QUERY WORKSPACE

Uygulamanın merkezinde gelişmiş bir Query Workspace olacak.

Database provider'a göre query language değişebilmeli.

MongoDB:

```javascript
db.users.find({
  status: "active"
})
```

PostgreSQL:

```sql
SELECT *
FROM users
WHERE status = 'active';
```

Redis:

```text
GET user:123
```

gibi.

Query Editor provider-aware olmalı.

Araştır:

* Syntax highlighting
* Autocomplete
* Code completion
* Database-aware autocomplete
* Collection/table autocomplete
* Field/column autocomplete
* Function autocomplete
* Query history
* Saved queries
* Query snippets
* Multi-tab query editor
* Query execution
* Query cancellation
* Timeout
* Error handling
* Execution duration
* Result pagination
* Explain plan

gibi özelliklerin nasıl uygulanacağını belirle.

---

# 12. AI QUERY ASSISTANT

Bu uygulamanın en önemli özelliğidir.

AI'ı ayrı bir chatbot olarak değil, **Query Workspace'in doğal bir parçası** olarak tasarla.

Ana akış:

```text
User Intent
     ↓
AI Query Assistant
     ↓
Database Context
     ↓
Generated Query
     ↓
Query Editor
     ↓
User Review
     ↓
User executes query
```

Örneğin MongoDB bağlıyken:

> "Son 7 gündeki başarısız SMS'leri operatöre göre grupla."

AI:

```javascript
db.SmsTransaction.aggregate([
  ...
])
```

üretebilir.

PostgreSQL bağlıyken aynı niyet:

```sql
SELECT ...
FROM ...
GROUP BY ...
```

üretebilmeli.

Redis bağlıyken Redis command üretebilmeli.

Dolayısıyla AI'ın yalnızca MongoDB query üretmesini değil:

> **Connected database provider'a uygun query language üretmesini**

istiyorum.

---

# 13. AI'IN YETKİLERİ

AI:

### Yapabilir

* Natural language → query
* Query explanation
* Query modification
* Query optimization
* Query correction
* Aggregation generation
* SQL generation
* MongoDB query generation
* Redis command suggestion
* Script generation
* Query documentation
* Explain plan analysis
* Index suggestion
* Schema-aware query generation

### Yapamaz

AI:

* INSERT
* UPDATE
* DELETE
* DROP
* ALTER
* CREATE INDEX
* Database migration
* Data modification

gibi işlemleri **kendi başına çalıştırmamalı.**

AI tarafından üretilen query/script:

**otomatik execute edilmemeli.**

Her zaman:

```text
AI
 ↓
Generated Query
 ↓
Query Editor
 ↓
User Review
 ↓
User clicks Run
```

akışı kullanılmalı.

---

# 14. AI CONTEXT SYSTEM

AI'ın kaliteli query üretmesi için database context oluştur.

Context provider'a göre dinamik olmalı.

MongoDB için:

```text
Database
Collections
Fields
Field Types
Sample Documents
Indexes
Current Query
Query History
Explain Result
```

PostgreSQL için:

```text
Database
Schemas
Tables
Columns
Column Types
Relations
Indexes
Constraints
Views
Current Query
Query History
Explain Result
```

gibi.

AI'a gereksiz bütün database'i gönderme.

**Context Builder** gerekli bilgileri seçip modele sağlamalı.

---

# 15. AI PROVIDER ARCHITECTURE

AI implementation'ını da provider abstraction ile tasarla.

Örneğin:

```text
AIProvider
│
├── LocalAIProvider
├── OllamaProvider
├── OpenAICompatibleProvider
└── DisabledProvider
```

gibi bir yapı değerlendir.

Ancak gereksiz abstraction oluşturma.

Önce mevcut AI SDK ve inference seçeneklerini araştır.

---

# 16. LOCAL AI

AI'ın mümkün olduğunca cihaz üzerinde çalışmasını istiyorum.

Araştır:

* llama.cpp
* GGUF
* Ollama
* ONNX Runtime
* ExecuTorch
* C++
* Rust
* Android GPU/NPU
* Windows GPU
* macOS Apple Silicon

gibi seçenekleri karşılaştır.

Özellikle query/code generation için uygun küçük modelleri araştır.

Model karşılaştırmasında:

* Model size
* RAM requirement
* VRAM requirement
* CPU performance
* GPU performance
* Mobile performance
* Windows performance
* macOS performance
* Quantization
* Context length
* Coding ability
* MongoDB/SQL knowledge
* Turkish language capability

gibi kriterleri kullan.

---

# 17. LOCAL + CLOUD AI

AI sistemi yalnızca local olmak zorunda değil.

İdeal olarak:

```text
AI Mode

○ Local
○ Cloud
○ Hybrid
○ Disabled
```

gibi bir yapı düşünülebilir.

Local AI:

* Privacy
* Offline usage
* Database schema'nın cihazdan çıkmaması

avantajlarını sağlamalı.

Cloud AI seçilirse kullanıcıya açık şekilde hangi bilgilerin AI provider'a gönderildiği gösterilmeli.

---

# 18. DATABASE PRIVACY

Database credentials hiçbir şekilde AI modeline gönderilmemeli.

AI'a:

```text
MongoDB URI
Password
API Key
TLS private key
```

gibi credential'lar verilmemeli.

AI context yalnızca query generation için gerekli metadata'yı içermeli.

Ayrıca hassas alanların AI context'ine gönderilmemesi için gelecekte:

```text
Sensitive Fields
Excluded Fields
Masking
Sampling Rules
```

gibi mekanizmaların eklenebilirliğini araştır.

---

# 19. AI QUERY EXPERIENCE

AI'ı klasik chatbot şeklinde tasarlamak istemiyorum.

Örneğin Query Workspace'te:

```text
┌─────────────────────────────────────┐
│ AI Query Assistant                  │
│                                     │
│ What do you want to query?          │
│                                     │
│ "Last 7 days failed SMS by operator"│
│                                     │
│ [Generate Query]                    │
└─────────────────────────────────────┘
```

ve generated query:

```text
┌─────────────────────────────────────┐
│ Generated Query                     │
│                                     │
│ db.SmsTransaction.aggregate(...)    │
│                                     │
│ [Insert into Editor]                │
└─────────────────────────────────────┘
```

gibi çalışabilir.

Ayrıca mevcut query üzerinde:

> "Bunu son 30 günle sınırla."

> "Aggregation'a çevir."

> "Bu sorgu neden yavaş?"

> "Bu sorguyu optimize et."

> "Bunu açıkla."

gibi context-aware AI işlemleri yapılabilmeli.

---

# 20. AI CHAT DEĞİL, QUERY COPILOT

Ürünün temel UX prensibi:

> AI bir chatbot değil, database query copilot olmalı.

Chat interface gerekiyorsa Query Workspace içerisinde yardımcı bir araç olarak bulunabilir.

Ana ürün:

```text
Database Explorer
+
Query Workspace
+
AI Query Assistant
```

olmalı.

---

# 21. DESKTOP UX

Desktop için çok panelli database workbench yaklaşımını araştır.

Örneğin:

```text
┌────────────────┬─────────────────────────────────┐
│ Connections    │ Query Workspace                 │
│                │                                 │
│ Databases      │ AI Query Assistant              │
│                │                                 │
│ Collections    │ Query Editor                    │
│                │                                 │
│ Tables         ├─────────────────────────────────┤
│                │ Query Results                   │
│                │                                 │
└────────────────┴─────────────────────────────────┘
```

Ancak bu sadece örnek.

F_AISUBCRIBE tasarım dilini referans alarak daha iyi bir UX öner.

---

# 22. MOBILE UX

Mobile uygulama desktop UI'ın küçültülmüş versiyonu olmamalı.

Mobile için adaptive navigation düşün.

Örneğin:

```text
Connections
   ↓
Database
   ↓
Collection
   ↓
Documents
```

Query Assistant mobilde hızlı erişilebilir olmalı.

Query Editor mobilde de kullanılabilir olmalı ancak mobil input ergonomisini dikkate al.

Flutter'ın adaptive/responsive yeteneklerini araştır.

---

# 23. ARCHITECTURE

**Pragmatic Clean Architecture** kullan.

Ancak over-engineering istemiyorum.

Şunlardan kaçın:

* Gereksiz interfaces
* Gereksiz repositories
* Gereksiz use-cases
* Gereksiz dependency injection
* Gereksiz abstraction
* Aşırı folder nesting
* Aşırı küçük dosyalara bölme

Mimari:

> **Simple enough to understand, structured enough to scale.**

olmalı.

Database provider architecture ile uygulamanın geri kalanını birbirinden izole et.

---

# 24. ÖNERİLEN KAVRAMSAL MİMARİ

Aşağıdaki yaklaşımı değerlendir:

```text
Flutter Application
│
├── Presentation
│
├── Application
│
├── Domain
│
│   ├── Database
│   │   ├── Connection
│   │   ├── Metadata
│   │   ├── Query
│   │   └── Capabilities
│   │
│   └── AI
│       ├── Query Assistant
│       ├── Context
│       └── Providers
│
└── Infrastructure
    │
    ├── Database Providers
    │   ├── MongoDB
    │   ├── PostgreSQL
    │   └── Future Providers
    │
    ├── AI Providers
    │   ├── Local
    │   ├── Ollama
    │   └── Cloud
    │
    └── Storage
```

Bu yapının doğru olup olmadığını araştır ve gerekiyorsa değiştir.

---

# 25. DATABASE PROVIDER PLUGIN MODEL

Uzun vadede yeni database eklemek mümkün olduğunca kolay olmalı.

Örneğin yeni bir PostgreSQL provider eklerken mevcut:

* UI
* Query Workspace
* AI Assistant
* Connection Manager

yeniden yazılmamalı.

Yeni provider yalnızca kendi:

```text
Connection
Metadata
Schema
Query
Capabilities
Data operations
```

implementasyonlarını sağlamalı.

Bunun gerçekçi olup olmadığını araştır.

Gerekirse provider registration/discovery mekanizması tasarla.

---

# 26. PERFORMANCE

Özellikle:

* Büyük collection
* Büyük document
* Büyük query result
* Query editor
* Syntax highlighting
* AI inference
* Database metadata
* Schema discovery

konularında performansa dikkat et.

UI thread'i bloklama.

Gerekirse:

* Isolate
* Background worker
* Native thread
* Streaming
* Lazy loading

kullan.

---

# 27. FUTURE DATABASE SUPPORT

Mimariyi şu database türlerine genişletmenin ne kadar mümkün olduğunu değerlendir:

### Relational

* PostgreSQL
* MySQL
* SQLite
* SQL Server

### Document

* MongoDB
* CouchDB

### Key-Value

* Redis

### Search / Analytics

* Elasticsearch
* OpenSearch

### Diğer

Uygulamanın bunları aynı UI içinde desteklemesi gerektiğini varsayma.

Her database türünün UX farklılıklarını araştır.

---

# 28. MVP

İlk MVP'de bütün database'leri desteklemeye çalışma.

İlk provider:

> **MongoDB**

olacak.

MVP:

```text
Connection Manager
        ↓
MongoDB Provider
        ↓
Database Explorer
        ↓
Collection Explorer
        ↓
Document Viewer
        ↓
Query Editor
        ↓
Query Results
        ↓
AI Query Assistant
```

olmalı.

Ancak architecture ilk günden:

```text
MongoDB only
```

şeklinde hard-code edilmemeli.

**MongoDB-first, database-agnostic architecture** hedeflenmeli.

---

# 29. FUTURE ROADMAP

MVP sonrasında aşağıdaki özellikleri değerlendirebilirsin:

* PostgreSQL provider
* MySQL provider
* Redis provider
* Elasticsearch/OpenSearch
* Aggregation visualizer
* Query performance analyzer
* Index advisor
* Schema visualization
* Database comparison
* Data export/import
* CSV/JSON export
* Saved queries
* Query snippets
* Query history
* AI query history
* AI debugging
* AI schema analysis
* AI index recommendations
* SSH tunnel
* Backup/restore
* Database migration assistant
* MCP integration
* Plugin/provider marketplace

Bunların hangilerinin gerçekten değerli olduğunu araştır.

---

# 30. SECURITY

Public release ihtimalini dikkate al.

Araştır:

* Secure credential storage
* Connection encryption
* TLS
* Certificate handling
* AI privacy
* Local AI security
* Cloud AI data transmission
* Query history encryption
* Sensitive field masking
* Logs
* Crash reports
* Analytics privacy

konularını.

---

# 31. TECHNOLOGY RESEARCH

Aşağıdaki kategorilerde güncel seçenekleri araştır:

### Flutter

* Flutter version
* Dart version
* Desktop support
* Mobile support
* Adaptive UI

### Database

* MongoDB Dart driver
* PostgreSQL Dart driver
* MySQL driver
* Redis client
* Native alternatives

### Editor

* Code editor
* Syntax highlighting
* Autocomplete
* Language server possibilities

### AI

* Local inference
* Cloud inference
* GGUF
* llama.cpp
* Ollama
* ONNX
* ExecuTorch
* Native C++/Rust

### Storage

* Secure storage
* Local database
* Query history
* Settings

### State management

Mevcut F_AISUBCRIBE yaklaşımını da değerlendir.

---

# 32. ARAŞTIRMA RAPORU FORMATı

İlk cevapta kod yazma.

Aşağıdaki başlıklarla teknik rapor hazırla:

## 1. Product Definition

Ürünü ve farklılaştırıcı özelliğini tanımla.

## 2. Architecture

Önerilen genel mimariyi diagram ile göster.

## 3. Database Abstraction

Database provider architecture'ı detaylandır.

## 4. MongoDB Provider

MongoDB bağlantı ve operasyon mimarisini açıkla.

## 5. Future Database Providers

PostgreSQL, Redis, Elasticsearch vb. eklenirken mimarinin nasıl genişleyeceğini göster.

## 6. Query Workspace

Query editor ve execution mimarisini öner.

## 7. AI Query Assistant

AI architecture, context system ve query generation sürecini açıkla.

## 8. Local AI

Güncel local AI seçeneklerini karşılaştır.

## 9. Security

Credential ve privacy modelini açıkla.

## 10. Desktop/Mobile UX

Her platform için UX yaklaşımı öner.

## 11. Performance

Büyük dataset ve local AI performans stratejisini belirle.

## 12. Flutter Architecture

Folder structure ve state management öner.

## 13. Technology Stack

Önerilen paket/kütüphaneleri ve nedenlerini tablo halinde göster.

## 14. MVP

İlk sürüm için kesin kapsamı belirle.

## 15. Roadmap

MVP sonrası aşamaları belirle.

## 16. Risks

Teknik riskleri ve alternatifleri belirt.

## 17. Final Recommendation

Sonuç olarak:

> "Bu projeyi şu mimari + şu teknolojiler + şu provider model + şu AI yaklaşımıyla geliştirmeyi öneriyorum."

şeklinde net bir karar ver.

---

# 33. SON VE EN ÖNEMLİ KURALLAR

Bu projede:

1. **Önce araştır.**
2. **Sonra seçenekleri karşılaştır.**
3. **Sonra mimari öner.**
4. **Ben onay vermeden implementation'a geçme.**
5. Güncel teknolojileri araştır.
6. MongoDB'yi ilk provider olarak kabul et fakat sistemi MongoDB'ye hard-code etme.
7. Farklı database paradigmalarını zorla tek modele sokma.
8. Common capabilities + provider-specific capabilities yaklaşımını değerlendir.
9. AI'ı autonomous database agent yapma.
10. AI'ın database üzerinde write authority'si olmasın.
11. AI tarafından oluşturulan query'ler otomatik çalıştırılmasın.
12. AI Query Assistant Query Workspace'in doğal bir parçası olsun.
13. Local AI öncelikli olsun ancak cloud provider desteğine açık architecture oluştur.
14. Database credentials hiçbir şekilde AI modeline gönderilmesin.
15. F_AISUBCRIBE projesinin tasarım dilini referans al.
16. Pragmatic Clean Architecture kullan.
17. Over-engineering yapma.
18. Desktop ve mobile UX'i ayrı değerlendir.
19. Büyük dataset'lerde performansı ilk günden düşün.
20. MVP'yi gereksiz özelliklerle şişirme.
21. Gelecekte yeni database provider eklemek mevcut sistemi yeniden yazmayı gerektirmemeli.

**Şimdi sadece araştırma ve teknik tasarım aşamasını gerçekleştir. Kod yazma.**
