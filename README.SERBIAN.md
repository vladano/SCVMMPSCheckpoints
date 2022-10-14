Ovo su powershell scriptovi za kreiranje/restor i brisanje checkpointa na Hyper-V VM-ovima koji se administriraju korišćenjem SCVMM 2019/2016 powershell komandi.
Posebno je tretiran problem kreiranja checkpointa na VM-ovima koji koriste .vhdx share diskove koji se koriste kod kreiranja MS SQL klastera sa 2 noda.
Korišćenjem shared HDD-a između 2 x VM se simulira konfiguracija MS SQL klastera kada baza se smesta na network lokaciju koja se fiziči nalazi na storage-u.

Prerequisite za funkcionisanje ovih skriptova je da je ime za svaku VM u sledecem formatu:
VM_NAME-System_Name
Ako imena VM-ova nije definisano u navedenom formatu potrebno je korigovati deo u okviru scriptova koji filtrira spisak virtualnih masina na način da može da obuhvati neku drugu logiku kojoj podležu vaše virtualne mašine.

## Kreiranja checkpointa na svim VM-ovima sa sistema

Pošto u mom slučaju sve virtualne mašine su članovi jednog ili više Windows Active Directory sistema na početku skripta se radi shutdown svih virtualnih mašina sa sistema jer samo u tom slučaju se može 100% garantovati da posle restore mašina će biti sigurno očuvan integritet svake VM unutar Active Directory domena.

Zatim se prolazi kroz ceo spisak VM-ova i radi dismount eventualnih DVD fajlova mountovanih na VM.

Da bi se omogućilo kreiranje checkpointa na VM-ovima sa shared .vhdx fajlom primenjen je sledeći algoritam:
- prodje se kroz sve VM i detektuje se da li na sistemu postoje VM sa shared .vhdx fajlovima
- odredi se količina potrebnog slobodnog prostora za backup shared .vhdx fajlova
- odradi se remove shared .vhdx fajlova sa VM-ova ako postoje
- odradi se kopiranje shared .vhdx fajlova na backup lokaciju
- odradi se kreiranje checkpointa na svim VM-ovima sa navedenog systema
- na VM-ove gde su ranije postajali shared .vhdx dikovi odradi se automatsko dodavanje shared .vhdx diskova
- odradi se refresh svih VM-ova sa sistema

## Restore checkpointa na svim VM-ovima sa sistema

- prolazi se kroz ceo spisak VM-ova sa sistema i napravi se spisak VM-ova sa shred .vhdx fajlovima.
- odradi se restor prethodno kreiranog checkpointa na virtualnim mašinama.
- zatim se sa navedene backup lokacije kopiraju prethodno tamo kopirani shared .vhdx fajlovi na originalnu lokaciju svake od VM-a.
- na VM-ove gde su ranije postajali shared .vhdx dikovi odradi se automatsko dodavanje shared .vhdx diskova
- odradi se refresh svih VM-ova sa sistema
