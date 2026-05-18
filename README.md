# NEXS Microkernel - Custom seL4 + Microkit Integration

Benvenuto nel codebase unificato di **NEXS Microkernel**, basato sulla combinazione del microkernel **seL4** (sicuro, ad alte prestazioni e formalmente verificato) e del framework statico **Microkit** (per lo sviluppo semplificato di sistemi basati su Protection Domain ad alto isolamento).

Il progetto è strutturato in modo da supportare in maniera nativa **tutte le architetture**, mantenendo intatti i **modelli di verifica formale** e tutte le **utility di sistema**, organizzandoli in cinque macro-directory principali.

---

## Mappatura Architetturale delle Cartelle

Tutte le risorse del progetto sono organizzate sistematicamente. Di seguito sono riportati i collegamenti standardizzati per ciascuna area del microkernel:

### 📂 1. [kernel/](file:///Users/olmo/Documents/git/nexskernel/kernel)
Contiene il core indipendente dall'architettura del microkernel seL4, i modelli di verifica formale e i moduli di supporto per le architetture non-ARM.
* **Core Logic**: Gestione dello schedulatore round-robin, capability (CNodes/CSpace), endpoint IPC sincroni e Thread Control Block (TCB).
* **[kernel/model/](file:///Users/olmo/Documents/git/nexskernel/kernel/model)**: Modelli per la verifica formale formale (Isabelle/HOL) mantenuti pienamente integri.
* **[kernel/api/](file:///Users/olmo/Documents/git/nexskernel/kernel/api)**: Definizioni e punti di ingresso delle chiamate di sistema (Syscalls).
* **Supporto Architetture Non-ARM**:
  - **[kernel/arch/riscv/](file:///Users/olmo/Documents/git/nexskernel/kernel/arch/riscv)**: File architetturali per RISC-V (32-bit e 64-bit).
  - **[kernel/arch/x86/](file:///Users/olmo/Documents/git/nexskernel/kernel/arch/x86)**: Supporto completo per sistemi x86 (IA32 e x86_64).

### 📂 2. [libkerl/](file:///Users/olmo/Documents/git/nexskernel/libkerl)
La libreria di runtime e l'interfaccia utente (user-space) del microkernel, compatibile con tutte le architetture supportate.
* **[libkerl/libsel4/](file:///Users/olmo/Documents/git/nexskernel/libkerl/libsel4)**: L'interfaccia client originale per invocare le syscall e manipolare le capability di seL4.
* **[libkerl/libmicrokit/](file:///Users/olmo/Documents/git/nexskernel/libkerl/libmicrokit)**: Le astrazioni runtime di Microkit (Protection Domain, canali di notifica, gestione I/O protetta) per definire task utente isolati.

### 📂 3. [aarch/](file:///Users/olmo/Documents/git/nexskernel/aarch)
Supporto architetturale dedicato per i processori ARM a 32-bit e 64-bit (AArch32 e AArch64).
* **[aarch/64/](file:///Users/olmo/Documents/git/nexskernel/aarch/64)**: Routine assembler a basso livello per AArch64, context switch, inizializzazione dei registri e gestione delle eccezioni.
* **[aarch/32/](file:///Users/olmo/Documents/git/nexskernel/aarch/32)**: File di compatibilità per processori ARMv7-A e AArch32.
* **[aarch/machine/](file:///Users/olmo/Documents/git/nexskernel/aarch/machine)**: Astrazioni e configurazioni del processore e dei registri hardware ARM.

### 📂 4. [driver/](file:///Users/olmo/Documents/git/nexskernel/driver)
Contiene i driver hardware eseguiti in spazio utente (User-Space Drivers) secondo la filosofia a microkernel.
* **[driver/dts/](file:///Users/olmo/Documents/git/nexskernel/driver/dts)**: Alberi dei dispositivi (Device Tree Source) personalizzati e overlays per schede di sviluppo e target fisici/virtuali.
* **Driver isolati**: Implementati come Protection Domain (es. console UART PL011 e controller di interrupt GICv2/v3).

### 📂 5. [root/](file:///Users/olmo/Documents/git/nexskernel/root)
Il nucleo di avvio e monitoraggio del sistema Microkit.
* **[root/loader/](file:///Users/olmo/Documents/git/nexskernel/root/loader)**: Il bootloader che prepara l'immagine di avvio seL4, alloca le risorse iniziali e carica gli ELF dei vari domini di protezione.
* **[root/monitor/](file:///Users/olmo/Documents/git/nexskernel/root/monitor)**: Monitor di sistema che gestisce a runtime i guasti, le notifiche asincrone e lo smistamento degli eventi tra domini.
* **[root/tool/](file:///Users/olmo/Documents/git/nexskernel/root/tool)**: Utility per il packaging e la validazione statica dell'architettura di sistema.

---

## Filosofia Architetturale: seL4 + Microkit

L'unione di seL4 e Microkit fornisce un'infrastruttura robusta e deterministica:
1. **Privilegio Minimo**: Il kernel ([kernel/](file:///Users/olmo/Documents/git/nexskernel/kernel)) opera al massimo livello di privilegio hardware (EL1/Ring 0), occupandosi unicamente di scheduling, IPC e delega di risorse tramite Capability.
2. **Isolamento Spazio Utente**: Tutti i driver ([driver/](file:///Users/olmo/Documents/git/nexskernel/driver)) e le applicazioni di sistema risiedono in *Protection Domain* (PD) distinti che comunicano esclusivamente tramite canali IPC dichiarati staticamente e validati a tempo di compilazione tramite i tool presenti in [root/tool/](file:///Users/olmo/Documents/git/nexskernel/root/tool).
3. **Astrazioni Semplificate**: Grazie a [libkerl/libmicrokit/](file:///Users/olmo/Documents/git/nexskernel/libkerl/libmicrokit), i programmatori possono sviluppare servizi di sistema complessi senza dover interagire direttamente con la complessa API nativa di seL4, beneficiando al contempo della sua assoluta sicurezza informatica.
