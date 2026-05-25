# Piano di Implementazione — Dynamic CPU Fallback & Riorganizzazione Workspace

Questo documento descrive in dettaglio le fasi necessarie per integrare il dynamic CPU fallback e riorganizzare i componenti `seL4` e `microkit` nel workspace di `nexskernel`, garantendo che il sistema compili ed esegua interamente da file locali tracciati e versionati in Git.

---

## 1. Configurazione Submodule & Branch `rust-sel4`

Prima di procedere con la riorganizzazione del kernel, configureremo il repository `rust-sel4` locale come un submodule ufficiale tracciato nel repository principale `nexs-kernel` (o `nexskernel`), puntando al repository GitHub dell'utente con il corretto branch.

### Passi di configurazione:
1. **Configurazione Repository Locale**:
   - Imposteremo il remote origin di `root/rust-sel4` su `https://github.com/olmox001/nexs-rust-sel4.git`.
   - Creeremo e faremo il checkout sul branch `sel4-support` (coerente con il branch del progetto principale) in `root/rust-sel4`.
2. **Aggiornamento di `.gitmodules`**:
   - Aggiungeremo la definizione del submodule in `.gitmodules`:
     ```ini
     [submodule "root/rust-sel4"]
     	path = root/rust-sel4
     	url = https://github.com/olmox001/nexs-rust-sel4.git
     	branch = sel4-support
     ```
3. **Tracciamento Submodule**:
   - Aggiungeremo il submodule all'indice Git per tracciare correttamente la revisione locale patchata.

---

## 2. Dynamic CPU Detection in CapDL Initializer

Modificheremo l'inizializzatore CapDL per rilevare a runtime il numero esatto di CPU attive su cui il sistema viene avviato.

### File: [initialize.rs](file:///Users/olmo/Documents/git/nexskernel/root/rust-sel4/crates/sel4-capdl-initializer/src/initialize.rs)
- Aggiorneremo la funzione `init_sched_context` per interrogare `self.bootinfo.inner().numNodes` (il numero reale di nodi CPU avviati dal kernel seL4).
  ```rust
  let active_cpus = usize::try_from(self.bootinfo.inner().numNodes).unwrap();
  ```
  Questo sostituisce il controllo statico `self.bootinfo.sched_control().len()` (che restituiva sempre la dimensione massima statica di `16`).
- Se l'affinità di una Protection Domain (PD) punta a un core non attivo (offline), verrà stampato un avviso in console e la PD verrà assegnata al core `0`, evitando crash o Page Fault.

---

## 3. Riorganizzazione del Kernel `seL4` Locale

Riorganizzeremo la cartella `kernel/` per trasformarla in un albero sorgente `seL4` completo e standard. Questo ci permetterà di compilare l'SDK direttamente da `kernel/` senza dipendere da cloni temporanei in `scratch/reference/seL4`.

### Struttura Standard di `seL4`:
1. **Creazione della Cartella `kernel/src`**:
   - Sposteremo tutte le directory flattened e i sorgenti C dall'architettura root di `kernel/` alla nuova cartella `kernel/src/`:
     - Cartelle: `api/`, `arch/`, `benchmark/`, `drivers/`, `fastpath/`, `kernel/`, `machine/`, `model/`, `object/`, `plat/`, `smp/`
     - File C: `util.c`, `inlines.c`, `assert.c`, `string.c`
2. **Integrazione di `config.cmake`**:
   - Copieremo `scratch/reference/seL4/src/config.cmake` in `kernel/src/config.cmake` per registrare correttamente tutte le sorgenti C durante la configurazione CMake.
3. **Integrazione di `libsel4`**:
   - Sposteremo `libkerl/libsel4` in `kernel/libsel4` in modo che le intestazioni e i binding C di seL4 risiedano nella cartella standard prevista dal build system.
4. **Integrazione Supporto ARM (aarch)**:
   - Copieremo l'intero contenuto della cartella `aarch/` in `kernel/src/arch/arm/` per integrare completamente il supporto ARM a 32 e 64 bit localmente.

---

## 4. Aggiornamenti del Build System

#### File: [Makefile](file:///Users/olmo/Documents/git/nexskernel/Makefile)
- Modificheremo `SEL4_SRC_DIR` per puntare alla cartella locale:
  ```makefile
  SEL4_SRC_DIR := $(ROOT_DIR)/kernel
  ```
- Correggeremo il target `kernel-merge` per copiare in modo ricorsivo e pulito tutti i file della cartella `aarch/` in `kernel/src/arch/arm/`.

#### File: [README.md](file:///Users/olmo/Documents/git/nexskernel/README.md)
- Aggiorneremo la documentazione del layout di cartelle rimuovendo i riferimenti a `scratch/reference/seL4` e descrivendo la nuova struttura pulita con `kernel/` e `root/rust-sel4/`.

---

## 5. Piano di Verifica

Eseguiremo i seguenti passi per testare la build e l'esecuzione:

1. **Ripulitura totale e ricostruzione SDK**:
   ```sh
   make clean-all
   make build-sdk-x86_64
   ```
2. **Compilazione ed esecuzione base-nexs**:
   ```sh
   make -C root/example/base-nexs clean
   make run-nexs-x86_64
   ```
3. **Test Retrocompatibilità Single-Core (Fallback)**:
   - Avvieremo QEMU con `-smp 1` modificando lo script `make-nexs-iso.sh`.
   - Verificheremo che le Protection Domains si avviino correttamente e che CapDL Initializer stampi i messaggi di avvertimento per la deviazione dei core offline su CPU 0 senza bloccarsi.
4. **Test Multi-Core SMP**:
   - Avvieremo QEMU con `-smp 4`.
   - Verificheremo la corretta distribuzione delle Protection Domains su ciascun core.
