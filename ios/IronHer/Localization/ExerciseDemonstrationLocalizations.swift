import Foundation

/// Technique cues and common mistakes keyed by stable exercise ID.
/// Demonstrations stay language-agnostic; only this copy is translated.
enum ExerciseDemonstrationLocalizations {
    struct FormCopy: Hashable {
        let cues: [String]
        let commonMistake: String?
    }

    static func formCopy(for exerciseId: String, language: AppLanguage) -> FormCopy? {
        let table = table(for: language)
        if let copy = table[exerciseId] {
            return copy
        }
        if language != .english {
            return english[exerciseId]
        }
        return nil
    }

    private static func table(for language: AppLanguage) -> [String: FormCopy] {
        switch language {
        case .english: return english
        case .german: return german
        case .serbian: return serbian
        case .spanish: return spanish
        }
    }

    // MARK: - English

    private static let english: [String: FormCopy] = [
        "overhead-press": FormCopy(
            cues: [
                "Brace your core and keep ribs down.",
                "Press the bar in a slight arc over your mid-foot.",
                "Lock out tall without shrugging.",
            ],
            commonMistake: "Leaning back to finish the press."
        ),
        "dumbbell-shoulder-press": FormCopy(
            cues: [
                "Start with dumbbells at shoulder height, palms forward.",
                "Press up until arms are long, wrists stacked.",
                "Lower with control to the start.",
            ],
            commonMistake: "Flaring elbows too wide and losing shoulder position."
        ),
        "machine-shoulder-press": FormCopy(
            cues: [
                "Set the seat so handles start near shoulder height.",
                "Keep your back against the pad.",
                "Press through a full, smooth range.",
            ],
            commonMistake: "Lifting off the seat to finish reps."
        ),
        "single-arm-dumbbell-overhead-press": FormCopy(
            cues: [
                "Brace hard so your torso stays square.",
                "Press the dumbbell overhead without leaning sideways.",
                "Return to the shoulder with control.",
            ],
            commonMistake: "Side-bending away from the working arm."
        ),
        "smith-overhead-press": FormCopy(
            cues: [
                "Set the bar path so it finishes over your mid-foot.",
                "Keep your core braced and glutes engaged.",
                "Press and lower without bouncing.",
            ],
            commonMistake: "Standing too far forward or behind the bar path."
        ),
        "arnold-press": FormCopy(
            cues: [
                "Start palms facing you at shoulder height.",
                "Rotate to palms-forward as you press up.",
                "Reverse the rotation on the way down.",
            ],
            commonMistake: "Rushing the rotation and losing elbow control."
        ),
        "overhead-tricep-extension": FormCopy(
            cues: [
                "Keep upper arms close to your ears.",
                "Only the forearms move as you extend.",
                "Stop short of locking out aggressively.",
            ],
            commonMistake: "Flaring elbows outward and turning it into a press."
        ),
        "tricep-extension": FormCopy(
            cues: [
                "Keep elbows pinned by your sides.",
                "Extend until the cable reaches full tension.",
                "Control the return without letting the stack slam.",
            ],
            commonMistake: "Using shoulder drive instead of elbow extension."
        ),
        "cable-overhead-extension": FormCopy(
            cues: [
                "Step forward enough to keep tension at the top.",
                "Upper arms stay still beside your head.",
                "Extend fully, then bend with control.",
            ],
            commonMistake: "Letting elbows drift forward each rep."
        ),
        "machine-tricep-extension": FormCopy(
            cues: [
                "Adjust the seat so pads meet your upper arms cleanly.",
                "Extend through the elbows only.",
                "Pause briefly without bouncing.",
            ],
            commonMistake: "Shrugging or leaning into the movement."
        ),
        "single-arm-dumbbell-tricep-extension": FormCopy(
            cues: [
                "Keep the upper arm vertical and still.",
                "Lower the dumbbell behind your head with control.",
                "Extend without swinging the torso.",
            ],
            commonMistake: "Opening the elbow angle out to the side."
        ),
        "skull-crusher": FormCopy(
            cues: [
                "Lie on a bench with upper arms mostly vertical.",
                "Bend only at the elbows toward your forehead.",
                "Extend back to the start without drifting elbows.",
            ],
            commonMistake: "Letting elbows flare or travel toward the hips."
        ),
        "ez-bar-skull-crusher": FormCopy(
            cues: [
                "Use a comfortable EZ-bar grip.",
                "Keep upper arms fixed as you bend the elbows.",
                "Extend smoothly to full length.",
            ],
            commonMistake: "Turning the move into a close-grip press."
        ),
        "dumbbell-skull-crusher": FormCopy(
            cues: [
                "Keep upper arms mostly fixed above the chest.",
                "Bend only at the elbows toward the sides of the head.",
                "Extend without letting the elbows drift.",
            ],
            commonMistake: "Turning the move into a close-grip press."
        ),
        "cable-skull-crusher": FormCopy(
            cues: [
                "Keep constant cable tension through the set.",
                "Upper arms stay nearly vertical.",
                "Extend and return in a short, clean arc.",
            ],
            commonMistake: "Sitting up or using body English between reps."
        ),
        "tricep-pushdown": FormCopy(
            cues: [
                "Elbows stay glued to your sides.",
                "Push down until arms are long.",
                "Return only as far as you can keep elbows still.",
            ],
            commonMistake: "Leaning over the cable and pressing with the chest."
        ),
        "rope-pushdown": FormCopy(
            cues: [
                "Start with the rope ends together.",
                "Extend and gently spread the rope at the bottom.",
                "Keep shoulders quiet.",
            ],
            commonMistake: "Pulling the rope apart with the shoulders."
        ),
        "barbell-bench-press": FormCopy(
            cues: [
                "Plant feet and set a stable upper back.",
                "Lower to mid-chest with control.",
                "Press up while keeping wrists stacked over elbows.",
            ],
            commonMistake: "Bouncing the bar off the chest."
        ),
        "dumbbell-bench-press": FormCopy(
            cues: [
                "Lower dumbbells with elbows about 45° from the torso.",
                "Stop when upper arms are roughly parallel to the floor.",
                "Press up without clanking the bells.",
            ],
            commonMistake: "Dropping too deep and losing shoulder control."
        ),
        "pull-up": FormCopy(
            cues: [
                "Start from a dead hang with shoulders set.",
                "Pull until chin clears the bar.",
                "Lower fully without swinging.",
            ],
            commonMistake: "Kipping or cutting the range short."
        ),
        "lat-pulldown": FormCopy(
            cues: [
                "Sit tall with a light lean back.",
                "Pull the bar to the upper chest.",
                "Control the return to a long arm position.",
            ],
            commonMistake: "Yanking the bar behind the neck."
        ),
        "barbell-back-squat": FormCopy(
            cues: [
                "Brace before you leave the rack.",
                "Sit the hips down and back with knees tracking toes.",
                "Drive up while keeping the bar over mid-foot.",
            ],
            commonMistake: "Collapsing the chest or letting heels rise."
        ),
        "goblet-squat": FormCopy(
            cues: [
                "Hold the weight close to your chest.",
                "Elbows stay inside the knees at the bottom.",
                "Stand tall without rushing the last third.",
            ],
            commonMistake: "Letting the weight drift forward."
        ),
        "romanian-deadlift": FormCopy(
            cues: [
                "Soft knees, hinge from the hips.",
                "Keep the bar close to your legs.",
                "Stop when you feel a strong hamstring stretch, then stand.",
            ],
            commonMistake: "Rounding the lower back to reach deeper."
        ),
        "lateral-raise": FormCopy(
            cues: [
                "Raise dumbbells to about shoulder height.",
                "Lead with the elbows, soft wrists.",
                "Lower slowly without shrugging.",
            ],
            commonMistake: "Using momentum and swinging the weights up."
        ),
        "plank": FormCopy(
            cues: [
                "Stack shoulders over elbows or wrists.",
                "Squeeze glutes and keep ribs down.",
                "Breathe steadily without sagging hips.",
            ],
            commonMistake: "Hiking the hips or dropping the lower back."
        ),
        "farmer-carry": FormCopy(
            cues: [
                "Stand tall with weights by your sides.",
                "Take short, controlled steps.",
                "Keep shoulders packed and grip firm.",
            ],
            commonMistake: "Leaning to one side or rushing the walk."
        ),
        "one-arm-dumbbell-row": FormCopy(
            cues: [
                "Hinge with a stable, supported torso.",
                "Pull the dumbbell toward your hip.",
                "Lower with control without rotating the shoulders.",
            ],
            commonMistake: "Yanking with the lower back instead of the arm."
        ),
        "single-leg-rdl": FormCopy(
            cues: [
                "Hinge from the hips on the standing leg.",
                "Keep a soft knee and a long, quiet spine.",
                "Return by driving the hips forward.",
            ],
            commonMistake: "Rounding the back or turning it into a squat."
        ),
        "bulgarian-split-squat": FormCopy(
            cues: [
                "Keep the front foot planted and stable.",
                "Lower until the front thigh is about parallel.",
                "Drive up through the front leg.",
            ],
            commonMistake: "Letting the front knee collapse inward."
        ),
        "forward-lunge": FormCopy(
            cues: [
                "Step forward and lower with control.",
                "Keep the torso upright.",
                "Push back to stand through the front foot.",
            ],
            commonMistake: "Slamming the back knee into the floor."
        ),
        "reverse-lunge": FormCopy(
            cues: [
                "Step back into a long, stable stance.",
                "Lower straight down with an upright torso.",
                "Drive through the front foot to stand.",
            ],
            commonMistake: "Leaning too far forward over the front leg."
        ),
        "step-up": FormCopy(
            cues: [
                "Place the whole working foot on the box.",
                "Drive up without pushing off the trailing leg.",
                "Stand tall before stepping down with control.",
            ],
            commonMistake: "Using the back leg to spring up."
        ),
        "single-leg-glute-bridge": FormCopy(
            cues: [
                "Plant one foot and keep the pelvis level.",
                "Drive the hips up through the heel.",
                "Pause briefly without overarching the low back.",
            ],
            commonMistake: "Twisting the hips toward the working side."
        ),
        "side-plank": FormCopy(
            cues: [
                "Stack shoulders over the supporting elbow.",
                "Lift the hips into a straight side line.",
                "Breathe steadily without collapsing.",
            ],
            commonMistake: "Letting the hips sag or rotate forward."
        ),
        "vertical-row": FormCopy(
            cues: [
                "Sit tall against the pad.",
                "Pull the handles toward the torso.",
                "Control the return without shrugging.",
            ],
            commonMistake: "Using momentum to finish the pull."
        ),
        "push-up": FormCopy(
            cues: [
                "Keep a straight line from head to heels.",
                "Lower with elbows about 45° from the torso.",
                "Press up without letting the hips sag.",
            ],
            commonMistake: "Flaring the elbows wide and dumping the shoulders."
        ),
    ]

    // MARK: - German

    private static let german: [String: FormCopy] = [
        "overhead-press": FormCopy(
            cues: [
                "Rumpf anspannen und Rippen unten halten.",
                "Die Stange leicht bogenförmig über den Mittelfuß drücken.",
                "Oben aufrichten, ohne die Schultern hochzuziehen.",
            ],
            commonMistake: "Nach hinten lehnen, um die Wiederholung zu beenden."
        ),
        "dumbbell-shoulder-press": FormCopy(
            cues: [
                "Start mit Kurzhanteln auf Schulterhöhe, Handflächen nach vorn.",
                "Nach oben drücken, bis die Arme lang sind.",
                "Kontrolliert in die Startposition absenken.",
            ],
            commonMistake: "Ellbogen zu weit öffnen und die Schulterposition verlieren."
        ),
        "machine-shoulder-press": FormCopy(
            cues: [
                "Sitz so einstellen, dass die Griffe auf Schulterhöhe starten.",
                "Rücken fest an der Lehne lassen.",
                "Durch einen vollen, ruhigen Bewegungsradius drücken.",
            ],
            commonMistake: "Vom Sitz abheben, um Wiederholungen zu schaffen."
        ),
        "single-arm-dumbbell-overhead-press": FormCopy(
            cues: [
                "Stark anspannen, damit der Rumpf gerade bleibt.",
                "Die Hantel nach oben drücken, ohne seitlich zu kippen.",
                "Kontrolliert zur Schulter zurückführen.",
            ],
            commonMistake: "Seitlich vom Arbeitsarm wegbeugen."
        ),
        "overhead-tricep-extension": FormCopy(
            cues: [
                "Oberarme nah an den Ohren halten.",
                "Nur die Unterarme bewegen sich.",
                "Nicht aggressiv durchdrücken.",
            ],
            commonMistake: "Ellbogen nach außen öffnen und daraus ein Drücken machen."
        ),
        "tricep-extension": FormCopy(
            cues: [
                "Ellbogen fest an den Seiten halten.",
                "Strecken, bis das Kabel volle Spannung hat.",
                "Rückweg kontrollieren, ohne den Stack knallen zu lassen.",
            ],
            commonMistake: "Mit der Schulter ziehen statt den Ellbogen zu strecken."
        ),
        "machine-tricep-extension": FormCopy(
            cues: [
                "Sitz so einstellen, dass die Pads sauber an den Oberarmen anliegen.",
                "Nur über die Ellbogen strecken.",
                "Kurz halten, ohne zu federn.",
            ],
            commonMistake: "Hochziehen der Schultern oder Reinlehnen."
        ),
        "skull-crusher": FormCopy(
            cues: [
                "Auf der Bank liegen, Oberarme weitgehend senkrecht.",
                "Nur in den Ellbogen zur Stirn beugen.",
                "Wieder strecken, ohne dass die Ellbogen wandern.",
            ],
            commonMistake: "Ellbogen öffnen oder Richtung Hüfte wandern lassen."
        ),
        "ez-bar-skull-crusher": FormCopy(
            cues: [
                "Angenehmen EZ-Bar-Griff wählen.",
                "Oberarme fixiert halten.",
                "Ruhig bis zur vollen Länge strecken.",
            ],
            commonMistake: "Die Bewegung in ein enggriffiges Bankdrücken verwandeln."
        ),
        "dumbbell-skull-crusher": FormCopy(
            cues: [
                "Hanteln mit Handflächen zueinander halten.",
                "Neben dem Kopf absenken, Ellbogen zeigen nach oben.",
                "Strecken, ohne die Gewichte zusammenzuschlagen.",
            ],
            commonMistake: "Ellbogen bei Ermüdung nach vorne fallen lassen."
        ),
        "barbell-bench-press": FormCopy(
            cues: [
                "Füße fest, oberen Rücken stabil setzen.",
                "Kontrolliert zur Brustmitte absenken.",
                "Hochdrücken, Handgelenke über den Ellbogen.",
            ],
            commonMistake: "Die Stange von der Brust abfedern."
        ),
        "pull-up": FormCopy(
            cues: [
                "Im Hang starten, Schultern setzen.",
                "Ziehen, bis das Kinn über der Stange ist.",
                "Voll absenken ohne Schwung.",
            ],
            commonMistake: "Kippen oder den Bewegungsumfang verkürzen."
        ),
        "barbell-back-squat": FormCopy(
            cues: [
                "Vor dem Abheben anspannen.",
                "Hüfte nach unten-hinten, Knie folgen den Zehen.",
                "Hochdrücken, Stange über dem Mittelfuß.",
            ],
            commonMistake: "Brust einfallen lassen oder Fersen anheben."
        ),
        "romanian-deadlift": FormCopy(
            cues: [
                "Knie weich, aus der Hüfte beugen.",
                "Stange nah an den Beinen halten.",
                "Stoppen bei starker Beinbeugerdehnung, dann aufrichten.",
            ],
            commonMistake: "Unteren Rücken runden, um tiefer zu kommen."
        ),
        "plank": FormCopy(
            cues: [
                "Schultern über Ellbogen oder Handgelenken.",
                "Gesäß anspannen, Rippen unten.",
                "Ruhig atmen, ohne durchzuhängen.",
            ],
            commonMistake: "Hüfte hochziehen oder den unteren Rücken absenken."
        ),
        "farmer-carry": FormCopy(
            cues: [
                "Aufrecht stehen, Gewichte seitlich.",
                "Kurze, kontrollierte Schritte.",
                "Schultern gepackt, Griff fest.",
            ],
            commonMistake: "Zur Seite lehnen oder hetzen."
        ),
    ]

    // MARK: - Serbian

    private static let serbian: [String: FormCopy] = [
        "overhead-press": FormCopy(
            cues: [
                "Aktiviraj trup i drži rebra dole.",
                "Guralo blago u luku iznad sredine stopala.",
                "Ispravi se gore bez slijeganja ramenima.",
            ],
            commonMistake: "Nagibanje unazad da bi se završio potisak."
        ),
        "dumbbell-shoulder-press": FormCopy(
            cues: [
                "Počni sa bučicama u visini ramena, dlanovi napred.",
                "Guraj gore dok ruke ne budu ispružene.",
                "Kontrolisano spusti u početni položaj.",
            ],
            commonMistake: "Širenje laktova previše u stranu."
        ),
        "machine-shoulder-press": FormCopy(
            cues: [
                "Podesi sedište tako da ručke počinju oko visine ramena.",
                "Leđa drži uz naslon.",
                "Guraj kroz pun, miran opseg pokreta.",
            ],
            commonMistake: "Podizanje sa sedišta da bi se završile ponavljanja."
        ),
        "single-arm-dumbbell-overhead-press": FormCopy(
            cues: [
                "Čvrsto stabilizuj trup da ostane ravan.",
                "Guraj bučicu gore bez nagibanja u stranu.",
                "Vrati kontrolisano do ramena.",
            ],
            commonMistake: "Savijanje tela od radne ruke."
        ),
        "overhead-tricep-extension": FormCopy(
            cues: [
                "Gornje ruke drži blizu ušiju.",
                "Pokreću se samo podlaktice.",
                "Ne zaključavaj agresivno na vrhu.",
            ],
            commonMistake: "Otvaranje laktova i pretvaranje u potisak."
        ),
        "tricep-extension": FormCopy(
            cues: [
                "Laktove drži uz bokove.",
                "Ispruži dok kabl ne dostigne punu tenziju.",
                "Kontroliši povratak bez udaranja tegova.",
            ],
            commonMistake: "Povlačenje ramenima umesto ekstenzije u laktu."
        ),
        "machine-tricep-extension": FormCopy(
            cues: [
                "Podesi sedište da jastuci leže čisto na nadlakticama.",
                "Ispružaj samo kroz laktove.",
                "Kratka pauza bez odskakanja.",
            ],
            commonMistake: "Slijeganje ramenima ili naslanjanje u pokret."
        ),
        "skull-crusher": FormCopy(
            cues: [
                "Lezi na klupu, nadlaktice uglavnom uspravne.",
                "Savijaj samo u laktovima prema čelu.",
                "Ispruži nazad bez pomeranja laktova.",
            ],
            commonMistake: "Širenje laktova ili njihovo pomeranje ka kukovima."
        ),
        "ez-bar-skull-crusher": FormCopy(
            cues: [
                "Koristi udoban EZ hvat.",
                "Nadlaktice ostaju fiksirane.",
                "Mirno ispruži do pune dužine.",
            ],
            commonMistake: "Pretvaranje pokreta u bench sa uskim hvatom."
        ),
        "dumbbell-skull-crusher": FormCopy(
            cues: [
                "Drži bučice dlanovima jedno prema drugom.",
                "Spusti pored glave, laktovi gore.",
                "Ispruži bez udaranja tegova.",
            ],
            commonMistake: "Padanje laktova napred kad dođe umor."
        ),
        "barbell-bench-press": FormCopy(
            cues: [
                "Stopala čvrsto, gornja leđa stabilna.",
                "Kontrolisano spusti na sredinu grudi.",
                "Guraj gore, zglobovi iznad laktova.",
            ],
            commonMistake: "Odbijanje šipke od grudi."
        ),
        "pull-up": FormCopy(
            cues: [
                "Počni iz mrtvog visa sa postavljenim ramenima.",
                "Povuci dok brada ne pređe preko šipke.",
                "Spusti se potpuno bez ljuljanja.",
            ],
            commonMistake: "Kipovanje ili skraćivanje opsega."
        ),
        "barbell-back-squat": FormCopy(
            cues: [
                "Aktiviraj trup pre silaska.",
                "Kukovi dole i nazad, kolena prate prste.",
                "Guraj gore, šipka iznad sredine stopala.",
            ],
            commonMistake: "Pad grudi ili podizanje peta."
        ),
        "romanian-deadlift": FormCopy(
            cues: [
                "Meko savijena kolena, pokret iz kukova.",
                "Šipku drži blizu nogu.",
                "Stani kad osetiš jak nateg zadnje lože, pa se ispravi.",
            ],
            commonMistake: "Zaobljavanje donjih leđa da bi se išlo dublje."
        ),
        "plank": FormCopy(
            cues: [
                "Ramena iznad laktova ili zglobova.",
                "Stegni gluteuse, rebra dole.",
                "Diši mirno bez padanja kukova.",
            ],
            commonMistake: "Dizanje kukova ili spuštanje donjih leđa."
        ),
        "farmer-carry": FormCopy(
            cues: [
                "Uspravno stani, tegovi uz bokove.",
                "Kratki, kontrolisani koraci.",
                "Ramena spakovana, stisak čvrst.",
            ],
            commonMistake: "Nagibanje na jednu stranu ili žurba."
        ),
    ]

    // MARK: - Spanish

    private static let spanish: [String: FormCopy] = [
        "overhead-press": FormCopy(
            cues: [
                "Activa el core y mantén las costillas abajo.",
                "Empuja la barra en un arco ligero sobre el mediopié.",
                "Extiende arriba sin encoger los hombros.",
            ],
            commonMistake: "Echarse hacia atrás para terminar el press."
        ),
        "dumbbell-shoulder-press": FormCopy(
            cues: [
                "Empieza con mancuernas a la altura de los hombros, palmas al frente.",
                "Empuja hasta estirar los brazos por completo.",
                "Baja con control hasta el inicio.",
            ],
            commonMistake: "Abrir demasiado los codos y perder la posición del hombro."
        ),
        "machine-shoulder-press": FormCopy(
            cues: [
                "Ajusta el asiento para que las agarres empiecen cerca del hombro.",
                "Mantén la espalda contra el respaldo.",
                "Empuja en un rango completo y suave.",
            ],
            commonMistake: "Levantarse del asiento para completar repeticiones."
        ),
        "single-arm-dumbbell-overhead-press": FormCopy(
            cues: [
                "Estabiliza el tronco para que no se tuerza.",
                "Empuja la mancuerna arriba sin inclinarte de lado.",
                "Vuelve al hombro con control.",
            ],
            commonMistake: "Inclinar el torso lejos del brazo que trabaja."
        ),
        "overhead-tricep-extension": FormCopy(
            cues: [
                "Mantén los brazos cerca de las orejas.",
                "Solo se mueven los antebrazos.",
                "No bloquees de forma agresiva arriba.",
            ],
            commonMistake: "Abrir los codos y convertir el movimiento en un press."
        ),
        "tricep-extension": FormCopy(
            cues: [
                "Codos pegados a los costados.",
                "Extiende hasta tensión completa del cable.",
                "Controla el regreso sin golpear la pila.",
            ],
            commonMistake: "Usar el hombro en lugar de extender el codo."
        ),
        "machine-tricep-extension": FormCopy(
            cues: [
                "Ajusta el asiento para que las almohadillas apoyen bien.",
                "Extiende solo desde los codos.",
                "Pausa breve sin rebotar.",
            ],
            commonMistake: "Encoger hombros o inclinarse hacia el movimiento."
        ),
        "skull-crusher": FormCopy(
            cues: [
                "Acuéstate con los brazos casi verticales.",
                "Dobla solo los codos hacia la frente.",
                "Extiende sin que los codos se desplacen.",
            ],
            commonMistake: "Abrir los codos o llevarlos hacia la cadera."
        ),
        "ez-bar-skull-crusher": FormCopy(
            cues: [
                "Usa un agarre cómodo en la barra EZ.",
                "Mantén los brazos fijos al doblar los codos.",
                "Extiende con suavidad hasta el final.",
            ],
            commonMistake: "Convertir el movimiento en un press de agarre cerrado."
        ),
        "dumbbell-skull-crusher": FormCopy(
            cues: [
                "Sujeta las mancuernas con las palmas enfrentadas.",
                "Baja junto a la cabeza, codos hacia arriba.",
                "Extiende sin chocar las mancuernas.",
            ],
            commonMistake: "Dejar caer los codos hacia adelante al fatigar."
        ),
        "barbell-bench-press": FormCopy(
            cues: [
                "Planta los pies y fija la espalda alta.",
                "Baja con control al pecho medio.",
                "Empuja arriba con muñecas sobre los codos.",
            ],
            commonMistake: "Rebotar la barra en el pecho."
        ),
        "pull-up": FormCopy(
            cues: [
                "Empieza en suspensión con hombros activos.",
                "Tira hasta que la barbilla pase la barra.",
                "Baja completo sin balancearte.",
            ],
            commonMistake: "Usar impulso o acortar el rango."
        ),
        "barbell-back-squat": FormCopy(
            cues: [
                "Activa el core antes de salir del rack.",
                "Siéntate atrás y abajo, rodillas siguiendo los pies.",
                "Sube manteniendo la barra sobre el mediopié.",
            ],
            commonMistake: "Colapsar el pecho o levantar los talones."
        ),
        "romanian-deadlift": FormCopy(
            cues: [
                "Rodillas suaves, bisagra desde la cadera.",
                "Mantén la barra cerca de las piernas.",
                "Para cuando sientas un buen estirón de isquios y vuelve.",
            ],
            commonMistake: "Redondear la zona lumbar para llegar más abajo."
        ),
        "plank": FormCopy(
            cues: [
                "Hombros sobre codos o muñecas.",
                "Aprieta glúteos y baja las costillas.",
                "Respira sin dejar caer la cadera.",
            ],
            commonMistake: "Subir la cadera o hundir la zona lumbar."
        ),
        "farmer-carry": FormCopy(
            cues: [
                "De pie erguida, pesas a los lados.",
                "Pasos cortos y controlados.",
                "Hombros firmes y agarre sólido.",
            ],
            commonMistake: "Inclinarse a un lado o caminar demasiado rápido."
        ),
    ]
}
