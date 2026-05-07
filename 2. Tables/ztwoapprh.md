# Panduan Lengkap: Membuat Table ZTWOAPPRH

**Transaksi:** SE11  
**Date:** February 2026

---

## 1. Urutan Pembuatan

```
┌─────────────────────────────────────────────────────────────────────┐
│              URUTAN PEMBUATAN OBJECT                                 │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  Step 1: Domain        → ZDOM_APPRSTS (values 0/1/2)               │
│          Harus dibuat pertama karena Data Element butuh Domain       │
│                                                                     │
│  Step 2: Data Element  → ZELE_APPRSTS (label & description)        │
│          Harus dibuat sebelum Table karena Table butuh Data Element  │
│                                                                     │
│  Step 3: Table         → ZTWOAPPRH (18 fields)                    │
│          Baru bisa dibuat setelah Domain & Data Element ready       │
│                                                                     │
│  Step 4: Technical Settings                                         │
│          Set data class & buffering                                 │
│                                                                     │
│  Step 5: TMG           → Table Maintenance Generator (SM30)         │
│          Supaya bisa maintain data via SM30                         │
│                                                                     │
│  Step 6: Verifikasi    → Cek semua object active                    │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 2. Step 1: Buat Domain ZDOM_APPRSTUS

Domain mendefinisikan **technical type** dan **fixed values** yang boleh diisi.

```
Transaksi: SE11
```

1. Buka **SE11**
2. Pilih radio button: **Domain**
3. Ketik: `ZDOM_APPRSTUS`
4. Klik **Create**

### Tab: Definition

| Field             | Isi dengan                |
| ----------------- | ------------------------- |
| Short Description | WO Approval Status Domain |
| Data Type         | CHAR                      |
| No. Characters    | 1                         |
| Output Length     | 1                         |

### Tab: Value Range → Fixed Values

Klik tab **Value Range**, isi baris per baris:

```
┌──────────────┬───────────────────────────┐
│ Single Value │ Short Description          │
├──────────────┼───────────────────────────┤
│ 0            │ No Approval                │
│ 1            │ Request Approval           │
│ 2            │ Parts Approved             │
└──────────────┴───────────────────────────┘
```

### Save & Activate

1. **Save** (Ctrl+S) → Assign package (contoh: ZWOM) → Assign transport request
2. **Activate** (Ctrl+F3)
3. Pastikan status bar bawah: **Object activated** ✓

---

## 3. Step 2: Buat Data Element ZDE_APPRSTUS

Data Element mendefinisikan **label** yang muncul di screen dan report.

```
Transaksi: SE11
```

1. Buka **SE11**
2. Pilih radio button: **Data type**
3. Ketik: `ZDE_APPRSTUS`
4. Klik **Create**
5. Popup muncul → Pilih **Data element** → Continue

### Tab: Definition

| Field             | Isi dengan                        |
| ----------------- | --------------------------------- |
| Short Description | WO Approval Status                |
| Category          | ● Domain (pilih radio button ini) |
| Domain Name       | ZDOM_APPRSTS                      |

### Tab: Field Label

| Label Type | Length | Text            |
| ---------- | ------ | --------------- |
| Short      | 10     | Appr.Sts        |
| Medium     | 15     | Approval Sts    |
| Long       | 20     | Approval Status |
| Heading    | 20     | Approval Status |

### Save & Activate

1. **Save** → Assign package & transport (sama dengan domain)
2. **Activate** (Ctrl+F3)
3. Status: **Object activated** ✓

---

## 4. Step 3: Buat Table ZTWOAPPR_H

```
Transaksi: SE11
```

1. Buka **SE11**
2. Pilih radio button: **Database table**
3. Ketik: `ZTWOAPPRH`
4. Klik **Create**

### Tab: Delivery and Maintenance

| Field                          | Isi dengan                      |
| ------------------------------ | ------------------------------- |
| Short Description              | WO Approval Header              |
| Delivery Class                 | **A** (Application table)       |
| Data Browser/Table View Maint. | **Display/Maintenance Allowed** |

### Tab: Fields (18 Fields)

Input satu per satu dari atas ke bawah:

```
┌────┬───────────────────┬─────┬──────┬──────────────┬────────────────────────────┐
│ No │ Field             │ Key │ Init │ Data Element │ Keterangan                  │
├────┼───────────────────┼─────┼──────┼──────────────┼────────────────────────────┤
│    │                   │     │      │              │                             │
│    │ ─── KEY ───       │     │      │              │                             │
│  1 │ MANDT             │  ✓  │  ✓   │ MANDT        │ Client                      │
│  2 │ AUFNR             │  ✓  │  ✓   │ AUFNR        │ Work Order Number           │
│    │                   │     │      │              │                             │
│    │ ─── STATUS ───    │     │      │              │                             │
│  3 │ APPR_STATUS       │     │      │ ZDE_APPRSTUS │ Approval Status (0/1/2)     │
│    │                   │     │      │              │                             │
│    │ ─── WO INFO ───   │     │      │              │                             │
│  4 │ WERKS             │     │      │ WERKS_D      │ Plant                       │
│  5 │ GSBER             │     │      │ GSBER        │ Business Area               │
│  6 │ AUART             │     │      │ AUFART       │ Order Type                  │
│    │                   │     │      │              │                             │
│    │ ─── REQUEST ───   │     │      │              │                             │
│  7 │ REQUESTED_BY      │     │      │ UNAME        │ Siapa yang trigger release  │
│  8 │ REQUESTED_DATE    │     │      │ DATUM        │ Tanggal first release       │
│  9 │ REQUESTED_TIME    │     │      │ UZEIT        │ Waktu first release         │
│    │                   │     │      │              │                             │
│    │ ─── FINAL ───     │     │      │              │                             │
│ 10 │ APPROVED_BY       │     │      │ UNAME        │ Final approver              │
│ 11 │ APPROVED_DATE     │     │      │ DATUM        │ Final approval date         │
│ 12 │ APPROVED_TIME     │     │      │ UZEIT        │ Final approval time         │
│    │                   │     │      │              │                             │
│    │ ─── AUDIT ───     │     │      │              │                             │
│ 13 │ CREATED_BY        │     │      │ UNAME        │ Created by                  │
│ 14 │ CREATED_DATE      │     │      │ DATUM        │ Creation date               │
│ 15 │ CREATED_TIME      │     │      │ UZEIT        │ Creation time               │
│ 16 │ CHANGED_BY        │     │      │ UNAME        │ Last changed by             │
│ 17 │ CHANGED_DATE      │     │      │ DATUM        │ Last change date            │
│ 18 │ CHANGED_TIME      │     │      │ UZEIT        │ Last change time            │
│    │                   │     │      │              │                             │
└────┴───────────────────┴─────┴──────┴──────────────┴────────────────────────────┘

Key  = Centang kolom "Key"
Init = Centang kolom "Initial Values"
Hanya field 1 (MANDT) dan 2 (AUFNR) yang Key + Init
Field 3-18 JANGAN centang Key dan Init
```

### Cara Input per Field di SE11

```
Contoh field pertama:
  Field name  : MANDT
  Key         : ☑ centang
  Init        : ☑ centang
  Data element: MANDT
  → Tekan Enter, label otomatis muncul

Contoh field ke-3:
  Field name  : APPR_STATUS
  Key         : ☐ jangan centang
  Init        : ☐ jangan centang
  Data element: ZELE_APPRSTS     ← custom data element kita
  → Tekan Enter, jika muncul "does not exist" → pastikan
    Step 2 sudah diactivate

Contoh field ke-7:
  Field name  : REQUESTED_BY
  Key         : ☐ jangan centang
  Init        : ☐ jangan centang
  Data element: UNAME
  → Tekan Enter, label "User Name" otomatis muncul

Ulangi untuk semua 18 field
```

---

## 5. Step 4: Technical Settings

Setelah 18 field selesai diinput:

1. Klik tombol **Technical Settings** di toolbar (atau menu: Goto → Technical Settings, atau Ctrl+Shift+F9)

| Field         | Isi dengan                | Keterangan                     |
| ------------- | ------------------------- | ------------------------------ |
| Data Class    | **APPL0**                 | Master data, transparent table |
| Size Category | **0**                     | Expected 0–5,400 records       |
| Buffering     | **Buffering Not Allowed** | Karena table sering di-UPDATE  |

```
┌────────────────────────────────────────────────────────┐
│ Technical Settings                                      │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Data Class:     APPL0                                  │
│ Size Category:  0                                      │
│                                                        │
│ Buffering:                                             │
│   ● Buffering Not Allowed                              │
│   ○ Buffering Allowed                                  │
│   ○ Buffering Switched On                              │
│                                                        │
└────────────────────────────────────────────────────────┘
```

2. **Save** di Technical Settings
3. Klik **Back** untuk kembali ke table definition

---

## 6. Step 5: Enhancement Category

1. Menu: **Extras → Enhancement Category**
2. Pilih: **Can Be Enhanced (Character-Type or Numeric)**
3. Klik **Copy** (✓)

---

## 7. Save & Activate Table

1. **Save** (Ctrl+S) → Assign package & transport
2. **Activate** (Ctrl+F3)
3. Jika ada popup **"Activate Dependent Objects"** → pilih object lalu klik Activate
4. Status bar: **Object activated** ✓

---

## 8. Step 6: Table Maintenance Generator (TMG)

Supaya admin bisa view/edit data via SM30.

### Langkah dari SE11

1. Buka ZTWOAPPR_H di **SE11** (Display mode)
2. Menu: **Utilities → Table Maintenance Generator**

### TMG Settings

| Field                  | Isi dengan     |
| ---------------------- | -------------- |
| Authorization Group    | &NC&           |
| Function Group         | ZTWOAPPR_H_MT  |
| Maintenance Type       | ● **One Step** |
| Maintenance Screen No. | 0001           |

```
┌────────────────────────────────────────────────────────┐
│ Table Maintenance Generator                             │
├────────────────────────────────────────────────────────┤
│                                                        │
│ Authorization Group: [  &NC&              ]            │
│ Function Group:      [  ZTWOAPPR_H_MT    ]            │
│                                                        │
│ Maintenance Type:                                      │
│   ● One Step                                           │
│   ○ Two Step                                           │
│                                                        │
│ Maintenance Screen Number: [ 0001 ]                    │
│                                                        │
│ [ Create ]                                             │
│                                                        │
└────────────────────────────────────────────────────────┘
```

1. Klik **Create**
2. Assign transport request
3. Tunggu sampai selesai → message "Maintenance dialog was generated"

### Test

```
Transaksi: SM30
Table/View: ZTWOAPPR_H
Klik [Maintain] atau [Display]
→ Grid muncul (kosong) = TMG berhasil ✓
```

---

## 9. Verifikasi Semua Object

```
┌─────────────────────────────────────────────────────────────────────┐
│                     CHECKLIST VERIFIKASI                             │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  [ ] Domain ZDOM_APPRSTS                                            │
│      SE11 → Domain → ZDOM_APPRSTS → Display                        │
│      → Active ✓                                                     │
│      → Type CHAR, Length 1                                          │
│      → Fixed values: 0, 1, 2                                       │
│                                                                     │
│  [ ] Data Element ZELE_APPRSTS                                      │
│      SE11 → Data type → ZELE_APPRSTS → Display                     │
│      → Active ✓                                                     │
│      → Domain: ZDOM_APPRSTS                                        │
│      → Labels: Short/Medium/Long/Heading terisi                    │
│                                                                     │
│  [ ] Table ZTWOAPPR_H                                               │
│      SE11 → Database table → ZTWOAPPR_H → Display                  │
│      → Active ✓                                                     │
│      → 18 fields terdaftar                                         │
│      → Key: MANDT + AUFNR                                          │
│      → Technical Settings: APPL0, Size 0, No Buffering             │
│      → Enhancement Category: set                                   │
│                                                                     │
│  [ ] Table Maintenance Generator                                    │
│      SM30 → ZTWOAPPR_H → Display                                   │
│      → Grid muncul tanpa error                                     │
│                                                                     │
│  [ ] Data Browser                                                   │
│      SE16 → ZTWOAPPR_H → Execute                                   │
│      → "0 entries selected"                                        │
│      → Semua 18 kolom terlihat                                     │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

## 10. Penjelasan: Dimana Approval Per Level Direcord

```
┌─────────────────────────────────────────────────────────────────────┐
│              RECORDING DATA DI 2 TABLE                              │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ZTWOAPPR_H (1 record per WO) → Record REQUEST TIME                │
│  ─────────────────────────────────────────────────                  │
│  • APPR_STATUS    : Overall status (0/1/2)                         │
│  • REQUESTED_BY   : Siapa yang klik Release pertama kali           │
│  • REQUESTED_DATE : Tanggal klik Release                           │
│  • REQUESTED_TIME : Jam klik Release                               │
│  • APPROVED_BY    : Siapa final approver (saat status → '2')      │
│  • APPROVED_DATE  : Tanggal final approval                         │
│  • APPROVED_TIME  : Jam final approval                             │
│                                                                     │
│       │ AUFNR (1 : N)                                               │
│       ▼                                                             │
│                                                                     │
│  ZTWOAPPR (N records per WO) → Record APPROVAL per LEVEL           │
│  ─────────────────────────────────────────────────────              │
│  • APPROVED_BY_L1   : Siapa BCSPPD yang approve (+ date + time)   │
│  • APPROVED_BY_L2   : Siapa PDH yang approve (+ date + time)      │
│  • APPROVED_BY_L3   : Siapa SDH yang approve (+ date + time)      │
│  • APPR_VALID       : Component ini sudah complete? (X / blank)    │
│  • MATCH_FLAG       : PN Match atau Mismatch                       │
│                                                                     │
│  Satu component = satu record,                                     │
│  jadi tiap component bisa punya approver yang berbeda              │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

### Contoh Data Setelah Full Approval

**ZTWOAPPR_H** (1 row):

```
┌──────────────┬─────┬──────┬────────────┬────────────┬────────────┬────────────┐
│ AUFNR        │ STS │WERKS │REQUESTED_BY│ REQ_DATE   │ APPROVED_BY│ APPR_DATE  │
├──────────────┼─────┼──────┼────────────┼────────────┼────────────┼────────────┤
│ 4000012345   │  2  │ JKT  │ PLANNER01  │ 2026-02-08 │ SDH_USER   │ 2026-02-11 │
└──────────────┴─────┴──────┴────────────┴────────────┴────────────┴────────────┘
  ↑ Hanya record: siapa request, kapan request, siapa final approve, kapan
```

**ZTWOAPPR** (3 rows untuk WO yang sama):

```
┌──────────────┬───────┬───────┬───────────┬──────────┬──────────┬──────┐
│ AUFNR        │ RSPOS │ MATCH │ L1 (BCSPPD)│ L2 (PDH) │ L3 (SDH)│VALID │
├──────────────┼───────┼───────┼───────────┼──────────┼──────────┼──────┤
│ 4000012345   │ 0001  │       │ BCSPPD01  │ PDH01    │ SDH01    │  X   │
│ 4000012345   │ 0002  │   X   │           │ PDH01    │ SDH01    │  X   │
│ 4000012345   │ 0003  │       │ BCSPPD01  │ PDH01    │ SDH01    │  X   │
└──────────────┴───────┴───────┴───────────┴──────────┴──────────┴──────┘
  ↑ Detail per component: siapa approve di tiap level, match/mismatch
  ↑ RSPOS 0002 = Match → L1 kosong (BCSPPD tidak perlu)
```

---

## 11. Troubleshooting

| Problem                                              | Solusi                                                                                     |
| ---------------------------------------------------- | ------------------------------------------------------------------------------------------ |
| "ZELE_APPRSTS does not exist" saat input field       | Pastikan Step 2 sudah di-activate. Kembali ke SE11 → Data type → ZELE_APPRSTS → cek active |
| "ZDOM_APPRSTS does not exist" saat buat data element | Pastikan Step 1 sudah di-activate                                                          |
| Technical Settings tidak bisa dibuka                 | Save table dulu (Ctrl+S), baru buka Technical Settings                                     |
| Activate error "Enhancement Category not maintained" | Menu Extras → Enhancement Category → pilih "Can Be Enhanced"                               |
| TMG error "Function Group already exists"            | Ganti nama function group, contoh: ZTWOAPPR_H_MNT                                          |
| SM30 error "No maintenance dialog"                   | Ulangi Step 8 (TMG), pastikan klik Create dan assign transport                             |

---

_End of Panduan Pembuatan ZTWOAPPR_H_
