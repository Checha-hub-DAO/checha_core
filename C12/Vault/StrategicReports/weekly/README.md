\# 📑 Weekly Reports — DAO-GOGS



Ця директорія містить щотижневі \*\*Matrix Audit Reports\*\* та \*\*Матриці архітектури\*\*.



---



\## 🧭 1. Matrix Audit Report (Markdown)



Файл: `Matrix\_Audit\_YYYY-MM-DD.md`  



\### Що всередині:

\- \*\*Підсумки станів\*\* → кількість модулів у статусах Core / Active / Draft / Archived.  

\- \*\*Розбіжності\*\* → що не співпадає між MODULE\_INDEX.md та manifest.md  

&nbsp; (версія, статус, відсутній manifest).  

\- \*\*Рекомендації\*\* → список конкретних дій (вирівняти версії, створити manifest тощо).



\### Як читати:

\- 🟢 Якщо "Розбіжностей не виявлено" → архітектура синхронізована.  

\- ⚠️ Якщо є таблиця з кодами → ці модулі треба оновити.  

\- ❗ Якщо скрипт повернув ExitCode=1 → критичні проблеми (версії/статуси/відсутні manifest).



---



\## 🗂 2. Матриця архітектури



Файли:

\- `architecture\_matrix.csv`  

\- `ARCHITECTURE\_MATRIX.md`



\### Що містить:

\- \*\*Code\*\* — код модуля (G11, G23, G45.1 …).  

\- \*\*Name\*\* — назва.  

\- \*\*Layer\*\* — рівень (Strategy, Security, Research …).  

\- \*\*Status\*\* — Draft / Active / Core / Archived.  

\- \*\*Version\*\* — версія з manifest.md.  

\- \*\*Parent\*\* — для підмодулів (наприклад, G44 для G45.1).  

\- \*\*Links\*\* — прив’язки до інших G- та C-блоків.  

\- \*\*Priority\*\* — A/B/C (якщо є у MODULE\_INDEX.md).  

\- \*\*Maturity (0–3)\*\* — рівень зрілості (0=архів, 1=каркас, 2=робочий, 3=ядро).  

\- \*\*Last Update\*\* — дата останнього оновлення manifest.md.



\### Як використовувати:

\- CSV → для фільтрації/аналітики (Excel, Power BI, Looker).  

\- MD → для швидкого перегляду в Git або GitBook.



---



\## 🔄 3. Режим використання



1\. Щотижня запускається скрипт \*\*`New-MatrixAudit.ps1`\*\*.  

2\. Генеруються три файли:  

&nbsp;  - `Matrix\_Audit\_YYYY-MM-DD.md`  

&nbsp;  - `architecture\_matrix.csv`  

&nbsp;  - `ARCHITECTURE\_MATRIX.md`  

3\. Якщо є критичні розбіжності → ExitCode=1 → пишеться лог у `C03\\LOG\\LOG.md`.  

4\. Команда переглядає Audit Report і вносить зміни у manifest.md / MODULE\_INDEX.md.  



---



\## 📌 Примітки

\- Джерело істини: \*\*manifest.md\*\* у кожному модулі.  

\- MODULE\_INDEX.md — оглядова таблиця, яка має збігатися з manifest.  

\- Матриця архітектури = "панель приладів".  

\- Audit Report = "інспектор".



---



