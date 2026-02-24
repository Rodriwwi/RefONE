import SwiftUI
import MapKit
import HealthKit
import Charts
import Combine

// MARK: - Estructuras de Ayuda

struct GridKey: Hashable {
    let x: Int
    let y: Int
}

struct HeatBin: Identifiable {
    let id = UUID()
    let center: CLLocationCoordinate2D
    let intensity: Double
    
    func polygonCoordinates(gridSizeDegrees: Double) -> [CLLocationCoordinate2D] {
        let halfSize = gridSizeDegrees / 2.0
        return [
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude - halfSize),
            CLLocationCoordinate2D(latitude: center.latitude - halfSize, longitude: center.longitude + halfSize),
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude + halfSize),
            CLLocationCoordinate2D(latitude: center.latitude + halfSize, longitude: center.longitude - halfSize)
        ]
    }
    
    var color: Color {
        if intensity > 0.75 { return Color.red.opacity(0.6) }
        else if intensity > 0.40 { return Color.orange.opacity(0.5) }
        else { return Color.yellow.opacity(0.4) }
    }
}

struct VirtualHeatBin: Identifiable {
    let id = UUID()
    let x: Double
    let y: Double
    let intensity: Double
    
    var color: Color {
        if intensity > 0.75 { return Color.red }
        else if intensity > 0.40 { return Color.orange }
        else { return Color.yellow }
    }
}

struct DatoZona: Identifiable {
    let id = UUID()
    let nombre: String
    let minutos: Double
    let color: Color
}

// MARK: - Vista Principal

struct DetallePartidoView: View {
    @Bindable var partido: Partido
    @StateObject private var vm = DetallePartidoViewModel()
    
    @State private var mostrandoEdicion = false
    @State private var mostrandoCalibrador = false
    @State private var mostrandoSelectorEntrenamiento = false
    @State private var tipoMapa: Int = 0
    
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    @AppStorage("limiteZ1") private var limiteZ1: Double = 0.60
    @AppStorage("limiteZ2") private var limiteZ2: Double = 0.70
    @AppStorage("limiteZ3") private var limiteZ3: Double = 0.80
    @AppStorage("limiteZ4") private var limiteZ4: Double = 0.90
    
    private let heatGridSize = 0.00002
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                Text(partido.fecha.formatted(date: .long, time: .shortened))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.top, 20)
                
                HStack {
                    Image(systemName: "sportscourt")
                    Text(partido.equipoLocal?.estadio?.nombre ?? "Estadio desconocido")
                }
                .font(.headline)
                .padding(.top, 5)
                
                HStack(alignment: .center, spacing: 30) {
                    VStack {
                        ImagenEscudo(data: partido.equipoLocal?.escudoData, size: 70)
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.headline).lineLimit(1)
                        Rectangle().fill((!partido.colorLocalHexPartido.isEmpty ? partido.colorLocalHexPartido : partido.equipoLocal?.colorHex ?? "#000000").toColor()).frame(height: 4)
                    }
                    .frame(width: 100)
                    
                    VStack {
                        Text("\(partido.golesLocal) - \(partido.golesVisitante)")
                            .font(.system(size: 40, weight: .heavy)).monospacedDigit()
                        Text("FINAL").font(.caption).foregroundStyle(.gray)
                    }
                    
                    VStack {
                        ImagenEscudo(data: partido.equipoVisitante?.escudoData, size: 70)
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.headline).lineLimit(1)
                        Rectangle().fill((!partido.colorVisitanteHexPartido.isEmpty ? partido.colorVisitanteHexPartido : partido.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF").toColor()).frame(height: 4)
                    }
                    .frame(width: 100)
                }
                .padding(.vertical, 20)
                
                if partido.costeDesplazamiento > 0 {
                    HStack {
                        Image(systemName: "car.fill")
                        Text("Desplazamiento: \(partido.costeDesplazamiento.formatted(.currency(code: "EUR")))")
                    }
                    .font(.caption).bold().foregroundStyle(.green)
                    .padding(6).background(Color.green.opacity(0.1)).cornerRadius(5).padding(.bottom, 5)
                }
                
                Text(partido.categoria?.nombre.uppercased() ?? "AMISTOSO")
                    .font(.caption).bold().padding(6).background(Color.gray.opacity(0.1)).cornerRadius(5)
                
                Divider().padding(.vertical, 20)
                
                if vm.datosDisponibles {
                    VStack(alignment: .leading, spacing: 30) {
                        HStack {
                            Text("Rendimiento Físico").font(.title2).bold()
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 15) {
                            DatoMetricView(titulo: "Duración", valor: vm.duracionString, icono: "stopwatch", color: .blue)
                            DatoMetricView(titulo: "Distancia", valor: String(format: "%.2f km", vm.distancia / 1000), icono: "figure.run", color: .green)
                            DatoMetricView(titulo: "Calorías", valor: String(format: "%.0f kcal", vm.calorias), icono: "flame.fill", color: .orange)
                            DatoMetricView(titulo: "Frecuencia Media", valor:String(format: "%.0f bpm", vm.ppmMedia), icono: "heart.fill", color: .red)
                            
                            if vm.velocidadMaxima > 0.5 {
                                DatoMetricView(titulo: "Velocidad Máx", valor: String(format: "%.1f km/h", vm.velocidadMaxima), icono: "speedometer", color: .purple)
                            } else {
                                let mins = vm.duracionTotal / 60
                                let cadencia = mins > 0 ? Double(vm.pasosTotales) / mins : 0
                                DatoMetricView(titulo: "Cadencia Media", valor: "\(Int(cadencia)) pasos/min", icono: "figure.step.training", color: .purple)
                            }
                            
                            DatoMetricView(titulo: "Pasos Totales", valor: "\(vm.pasosTotales)", icono: "shoeprints.fill", color: .cyan)
                        }
                        .padding(.horizontal)
                        
                        if !vm.heatMapBins.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("Mapa de Calor").font(.headline)
                                    Spacer()
                                    if tipoMapa == 1 {
                                        Button { mostrandoCalibrador = true } label: { Image(systemName: "scope").font(.title3) }
                                        .padding(.trailing, 8)
                                    }
                                    Picker("Tipo Mapa", selection: $tipoMapa) {
                                        Image(systemName: "globe.europe.africa.fill").tag(0)
                                        Image(systemName: "square.grid.2x2").tag(1)
                                    }
                                    .pickerStyle(.segmented).frame(width: 120)
                                    .onChange(of: tipoMapa) { _, nuevo in
                                        if nuevo == 1 && vm.esquinasUsuario.count < 3 { mostrandoCalibrador = true }
                                    }
                                }
                                .padding(.horizontal)
                                
                                ZStack {
                                    if tipoMapa == 0 {
                                        Map {
                                            ForEach(vm.heatMapBins) { bin in
                                                MapPolygon(coordinates: bin.polygonCoordinates(gridSizeDegrees: heatGridSize))
                                                    .foregroundStyle(bin.color)
                                            }
                                        }.mapStyle(.imagery(elevation: .realistic))
                                    } else {
                                        CampoFutbolView().overlay {
                                            GeometryReader { geo in
                                                Canvas { context, size in
                                                    let radio = size.width * 0.08
                                                    for bin in vm.virtualHeatBins {
                                                        let rect = CGRect(x: (bin.x * size.width) - (radio/2), y: (bin.y * size.height) - (radio/2), width: radio, height: radio)
                                                        context.fill(Path(ellipseIn: rect), with: .color(bin.color.opacity(0.4)))
                                                    }
                                                }.blur(radius: 10).mask(RoundedRectangle(cornerRadius: 8))
                                            }
                                        }
                                    }
                                }.frame(height: 450).cornerRadius(12).padding(.horizontal).animation(.easeInOut, value: tipoMapa)
                            }
                        }
                        
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Zonas de Esfuerzo").font(.headline).padding(.horizontal)
                            Chart(vm.zonasCardiacas) { zona in
                                BarMark(x: .value("Zona", zona.nombre), y: .value("Minutos", zona.minutos))
                                    .foregroundStyle(zona.color).cornerRadius(4)
                                    .annotation(position: .top) { Text("\(String(format: "%.0f", zona.minutos))m").font(.caption2).foregroundStyle(.secondary) }
                            }.chartYAxisLabel("Minutos").frame(height: 220).padding(.horizontal)
                            
                            VStack(spacing: 8) {
                                Group {
                                    HStack { Circle().fill(Color.blue.opacity(0.6)).frame(width: 8, height: 8); Text("Zona 1 (< \(Int(fcMax * limiteZ1)) bpm)"); Spacer() }
                                    HStack { Circle().fill(Color.green.opacity(0.8)).frame(width: 8, height: 8); Text("Zona 2 (\(Int(fcMax * limiteZ1))-\(Int(fcMax * limiteZ2)) bpm)"); Spacer() }
                                    HStack { Circle().fill(Color.yellow).frame(width: 8, height: 8); Text("Zona 3 (\(Int(fcMax * limiteZ2))-\(Int(fcMax * limiteZ3)) bpm)"); Spacer() }
                                    HStack { Circle().fill(Color.orange).frame(width: 8, height: 8); Text("Zona 4 (\(Int(fcMax * limiteZ3))-\(Int(fcMax * limiteZ4)) bpm)"); Spacer() }
                                    HStack { Circle().fill(Color.red).frame(width: 8, height: 8); Text("Zona 5 (> \(Int(fcMax * limiteZ4)) bpm)"); Spacer() }
                                }.font(.caption2).foregroundStyle(.secondary)
                            }.padding(.horizontal, 20).padding(.bottom, 10)
                        }
                    }
                } else if vm.cargando {
                    VStack(spacing: 15) {
                        ProgressView().scaleEffect(1.5)
                        Text("Analizando datos de Salud...").font(.subheadline).foregroundStyle(.secondary)
                    }.frame(height: 200)
                } else {
                    ContentUnavailableView {
                        Label("Datos no disponibles", systemImage: "heart.slash.circle")
                    } description: {
                        Text(vm.mensajeError ?? "No se encontró información del reloj para este partido.")
                    } actions: {
                        Button("Vincular entrenamiento") {
                            mostrandoSelectorEntrenamiento = true
                        }
                        .buttonStyle(.borderedProminent)
                        .padding(.top, 10)
                    }
                    .padding(.top, 40)
                }
            }
            .padding(.bottom, 50)
        }
        .navigationTitle("Detalle Partido")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Editar") { mostrandoEdicion = true }
            }
        }
        .sheet(isPresented: $mostrandoEdicion) {
            NavigationStack { EditarPartidoView(partido: partido) }
                .presentationDetents([.medium, .large])
        }
        .sheet(isPresented: $mostrandoCalibrador) {
            CalibradorCampoView(rutaGPS: vm.rutaCoordenadasPublica) { esquinas in
                vm.esquinasUsuario = esquinas
                vm.generarMapaCalor()
            }
        }
        .sheet(isPresented: $mostrandoSelectorEntrenamiento) {
            SelectorEntrenamientoView(vm: vm, partido: partido)
        }
        .onAppear {
            vm.actualizarConfiguracion(fcMax: fcMax, l1: limiteZ1, l2: limiteZ2, l3: limiteZ3, l4: limiteZ4)
            vm.cargarEntrenamiento(id: partido.workoutID)
        }
        .onDisappear {
            if vm.distancia > 0 {
                partido.distanciaRecorrida = vm.distancia
                partido.caloriasQuemadas = vm.calorias
            }
        }
    }
}

// MARK: - Vista Selector Entrenamiento Manual

struct SelectorEntrenamientoView: View {
    @Environment(\.dismiss) var dismiss
    @ObservedObject var vm: DetallePartidoViewModel
    var partido: Partido
    
    var body: some View {
        NavigationStack {
            List(vm.entrenamientosRecientes, id: \.uuid) { workout in
                Button {
                    vm.vincularEntrenamiento(workout, a: partido)
                    dismiss()
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(workout.startDate.formatted(date: .abbreviated, time: .shortened))
                            .font(.headline)
                        
                        HStack {
                            Text("\(Int(workout.duration / 60)) min")
                            if let kcal = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) {
                                Text("• \(Int(kcal)) kcal")
                            }
                            if let dist = workout.totalDistance?.doubleValue(for: .meter()) {
                                Text("• \(String(format: "%.2f", dist / 1000)) km")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .foregroundStyle(.primary)
            }
            .navigationTitle("Últimos Entrenamientos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .overlay {
                if vm.entrenamientosRecientes.isEmpty {
                    ProgressView()
                }
            }
            .onAppear {
                vm.buscarEntrenamientosRecientes()
            }
        }
    }
}

// MARK: - Vista Dibujada del Campo de Fútbol

struct CampoFutbolView: View {
    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [Color(hue: 0.35, saturation: 0.7, brightness: 0.6), Color(hue: 0.35, saturation: 0.7, brightness: 0.5)], startPoint: .top, endPoint: .bottom))
                
                Group {
                    Rectangle().stroke(.white.opacity(0.6), lineWidth: 2).padding(4)
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height / 2))
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height / 2))
                    }.stroke(.white.opacity(0.6), lineWidth: 2)
                    Circle().stroke(.white.opacity(0.6), lineWidth: 2).frame(width: geo.size.width * 0.3)
                    
                    Rectangle().stroke(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.15)
                        .position(x: geo.size.width / 2, y: geo.size.height * 0.075 + 4)
                    
                    Rectangle().stroke(.white.opacity(0.6), lineWidth: 2)
                        .frame(width: geo.size.width * 0.5, height: geo.size.height * 0.15)
                        .position(x: geo.size.width / 2, y: geo.size.height - (geo.size.height * 0.075) - 4)
                }
            }
        }
        .cornerRadius(8)
    }
}

// MARK: - Edit View

struct EditarPartidoView: View {
    @Environment(\.dismiss) var dismiss
    var partido: Partido
    @State private var coste: Double = 0.0
    @State private var golesL: Int = 0
    @State private var golesV: Int = 0
    @State private var colorL: Color = .black
    @State private var colorV: Color = .white
    @State private var usarColores: Bool = false
    
    var body: some View {
        Form {
            Section("Económico") {
                HStack { Text("Desplazamiento (€)"); TextField("0.0", value: $coste, format: .currency(code: "EUR")).keyboardType(.decimalPad) }
            }
            Section("Resultado") {
                Stepper("Goles Local: \(golesL)", value: $golesL)
                Stepper("Goles Visitante: \(golesV)", value: $golesV)
            }
            Section("Equipaciones") {
                Toggle("Colores Personalizados", isOn: $usarColores)
                if usarColores {
                    ColorPicker("Color Local", selection: $colorL)
                    ColorPicker("Color Visitante", selection: $colorV)
                }
            }
        }
        .navigationTitle("Editar Partido")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) { Button("Cancelar") { dismiss() } }
            ToolbarItem(placement: .confirmationAction) { Button("Guardar") { guardarCambios(); dismiss() }.bold() }
        }
        .onAppear {
            coste = partido.costeDesplazamiento
            golesL = partido.golesLocal
            golesV = partido.golesVisitante
            if !partido.colorLocalHexPartido.isEmpty {
                usarColores = true
                colorL = partido.colorLocalHexPartido.toColor()
                colorV = partido.colorVisitanteHexPartido.toColor()
            } else {
                colorL = partido.equipoLocal?.colorHex.toColor() ?? .black
                colorV = partido.equipoVisitante?.colorVisitanteHex.toColor() ?? .white
            }
        }
    }
    
    func guardarCambios() {
        partido.costeDesplazamiento = coste
        partido.golesLocal = golesL
        partido.golesVisitante = golesV
        partido.finalizado = true
        if usarColores {
            partido.colorLocalHexPartido = colorL.toHex() ?? "#000000"
            partido.colorVisitanteHexPartido = colorV.toHex() ?? "#FFFFFF"
        } else {
            partido.colorLocalHexPartido = ""
            partido.colorVisitanteHexPartido = ""
        }
    }
}

// MARK: - ViewModel

class DetallePartidoViewModel: ObservableObject {
    @Published var datosDisponibles = false
    @Published var cargando = true
    @Published var mensajeError: String? = nil
    
    @Published var calorias: Double = 0
    @Published var distancia: Double = 0
    @Published var ppmMedia: Double = 0
    @Published var duracionString: String = "--"
    @Published var duracionTotal: TimeInterval = 0
    @Published var velocidadMaxima: Double = 0
    @Published var pasosTotales: Int = 0
    @Published var zonasCardiacas: [DatoZona] = []
    
    @Published var heatMapBins: [HeatBin] = []
    @Published var virtualHeatBins: [VirtualHeatBin] = []
    @Published var rutaCoordenadasPublica: [CLLocationCoordinate2D] = []
    @Published var esquinasUsuario: [CLLocationCoordinate2D] = []
    
    @Published var entrenamientosRecientes: [HKWorkout] = []
    
    private var rutaCoordenadasRaw: [CLLocationCoordinate2D] = []
    private let healthStore = HKHealthStore()
    private let calculationGridSize = 0.00002
    
    private var fcMax: Double = 190.0
    private var limitZ1: Double = 0.60
    private var limitZ2: Double = 0.70
    private var limitZ3: Double = 0.80
    private var limitZ4: Double = 0.90
    
    func actualizarConfiguracion(fcMax: Double, l1: Double, l2: Double, l3: Double, l4: Double) {
        self.fcMax = fcMax; self.limitZ1 = l1; self.limitZ2 = l2; self.limitZ3 = l3; self.limitZ4 = l4
    }
    
    func cargarEntrenamiento(id: UUID?) {
        self.datosDisponibles = false; self.cargando = true; self.mensajeError = nil
        solicitarPermisosLectura()
        
        guard let id = id else {
            DispatchQueue.main.async { self.mensajeError = "No hay datos vinculados. Puedes asignar un entrenamiento manualmente."; self.cargando = false }
            return
        }
        
        let predicate = HKQuery.predicateForObject(with: id)
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: 1, sortDescriptors: nil) { _, samples, error in
            guard let workouts = samples as? [HKWorkout], let workout = workouts.first else {
                DispatchQueue.main.async { self.mensajeError = "No se encontró el registro en la App Salud."; self.cargando = false }
                return
            }
            DispatchQueue.main.async { self.procesarDatosReales(workout: workout) }
        }
        healthStore.execute(query)
    }
    
    func buscarEntrenamientosRecientes() {
        solicitarPermisosLectura()
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        
        let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: nil, limit: 15, sortDescriptors: [sortDescriptor]) { _, samples, _ in
            guard let workouts = samples as? [HKWorkout] else { return }
            DispatchQueue.main.async {
                self.entrenamientosRecientes = workouts
            }
        }
        healthStore.execute(query)
    }
    
    func vincularEntrenamiento(_ workout: HKWorkout, a partido: Partido) {
        partido.workoutID = workout.uuid
        self.cargando = true
        self.mensajeError = nil
        DispatchQueue.main.async {
            self.procesarDatosReales(workout: workout)
        }
    }
    
    func solicitarPermisosLectura() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let tipos: Set<HKObjectType> = [HKObjectType.workoutType(), HKSeriesType.workoutRoute(), HKObjectType.quantityType(forIdentifier: .heartRate)!, HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!, HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!, HKObjectType.quantityType(forIdentifier: .runningSpeed)!, HKObjectType.quantityType(forIdentifier: .stepCount)!]
        healthStore.requestAuthorization(toShare: nil, read: tipos) { _, _ in }
    }
    
    func procesarDatosReales(workout: HKWorkout) {
        self.calorias = workout.totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
        self.distancia = workout.totalDistance?.doubleValue(for: .meter()) ?? 0
        self.duracionTotal = workout.duration
        self.duracionString = self.formatearDuracion(workout.duration)
        
        self.cargarFrecuenciaCardiaca(workout: workout)
        self.cargarVelocidadMaxima(workout: workout)
        self.cargarPasos(workout: workout)
        self.cargarRuta(workout: workout)
        self.calcularZonasReales(workout: workout)
    }
    
    func cargarVelocidadMaxima(workout: HKWorkout) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .runningSpeed) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteMax) { _, res, _ in
            if let max = res?.maximumQuantity() {
                let val = max.doubleValue(for: HKUnit.meter().unitDivided(by: .second()))
                DispatchQueue.main.async { self.velocidadMaxima = val * 3.6 }
            }
        }
        healthStore.execute(query)
    }
    
    func cargarPasos(workout: HKWorkout) {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, res, _ in
            if let sum = res?.sumQuantity() {
                DispatchQueue.main.async { self.pasosTotales = Int(sum.doubleValue(for: .count())) }
            }
        }
        healthStore.execute(query)
    }
    
    func cargarFrecuenciaCardiaca(workout: HKWorkout) {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, res, _ in
            if let avg = res?.averageQuantity() {
                DispatchQueue.main.async { self.ppmMedia = avg.doubleValue(for: HKUnit(from: "count/min")) }
            }
        }
        healthStore.execute(query)
    }
    
    func calcularZonasReales(workout: HKWorkout) {
        let type = HKQuantityType.quantityType(forIdentifier: .heartRate)!
        let predicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]) { _, samples, _ in
            guard let muestras = samples as? [HKQuantitySample], !muestras.isEmpty else { return }
            var tZ1: TimeInterval = 0; var tZ2: TimeInterval = 0; var tZ3: TimeInterval = 0; var tZ4: TimeInterval = 0; var tZ5: TimeInterval = 0
            for i in 0..<(muestras.count - 1) {
                let actual = muestras[i]
                let dur = min(muestras[i+1].startDate.timeIntervalSince(actual.startDate), 10.0)
                let p = actual.quantity.doubleValue(for: HKUnit(from: "count/min")) / self.fcMax
                if p < self.limitZ1 { tZ1 += dur }
                else if p < self.limitZ2 { tZ2 += dur }
                else if p < self.limitZ3 { tZ3 += dur }
                else if p < self.limitZ4 { tZ4 += dur }
                else { tZ5 += dur }
            }
            DispatchQueue.main.async {
                self.zonasCardiacas = [
                    DatoZona(nombre: "Z1", minutos: tZ1/60, color: .blue.opacity(0.6)),
                    DatoZona(nombre: "Z2", minutos: tZ2/60, color: .green.opacity(0.8)),
                    DatoZona(nombre: "Z3", minutos: tZ3/60, color: .yellow),
                    DatoZona(nombre: "Z4", minutos: tZ4/60, color: .orange),
                    DatoZona(nombre: "Z5", minutos: tZ5/60, color: .red)
                ]
            }
        }
        healthStore.execute(query)
    }
    
    func cargarRuta(workout: HKWorkout) {
        self.rutaCoordenadasRaw = []
        let type = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)
        let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
            guard let rutas = samples as? [HKWorkoutRoute] else { DispatchQueue.main.async { self.finalizarCarga() }; return }
            let grupo = DispatchGroup()
            for ruta in rutas {
                grupo.enter()
                let q = HKWorkoutRouteQuery(route: ruta) { q, locs, done, err in
                    if let locs = locs { self.rutaCoordenadasRaw.append(contentsOf: locs.map { $0.coordinate }) }
                    if done { grupo.leave() }
                }
                self.healthStore.execute(q)
            }
            grupo.notify(queue: .main) {
                let raw = self.rutaCoordenadasRaw
                let clean = self.filtrarPuntosFueraDelCampo(raw)
                self.rutaCoordenadasPublica = clean
                self.rutaCoordenadasRaw = clean
                self.generarMapaCalor()
                self.finalizarCarga()
            }
        }
        healthStore.execute(query)
    }
    
    private func filtrarPuntosFueraDelCampo(_ puntos: [CLLocationCoordinate2D]) -> [CLLocationCoordinate2D] {
        guard !puntos.isEmpty else { return [] }
        let latProm = puntos.map { $0.latitude }.reduce(0, +) / Double(puntos.count)
        let lonProm = puntos.map { $0.longitude }.reduce(0, +) / Double(puntos.count)
        let centro = CLLocation(latitude: latProm, longitude: lonProm)
        return puntos.filter { CLLocation(latitude: $0.latitude, longitude: $0.longitude).distance(from: centro) < 85.0 }
    }
    
    func generarMapaCalor() {
        guard !rutaCoordenadasRaw.isEmpty else { return }
        
        var gridCounts: [GridKey: Int] = [:]
        var maxCount = 0
        
        for coord in rutaCoordenadasRaw {
            let gridX = Int(coord.latitude / calculationGridSize)
            let gridY = Int(coord.longitude / calculationGridSize)
            let key = GridKey(x: gridX, y: gridY)
            let count = (gridCounts[key] ?? 0) + 1
            gridCounts[key] = count
            maxCount = max(maxCount, count)
        }
        
        let saturacion = max(Double(maxCount) * 0.30, 2.0)
        
        var realBins: [HeatBin] = []
        for (key, count) in gridCounts {
            let centerLat = (Double(key.x) * calculationGridSize) + (calculationGridSize / 2.0)
            let centerLon = (Double(key.y) * calculationGridSize) + (calculationGridSize / 2.0)
            let intensity = min(Double(count) / saturacion, 1.0)
            realBins.append(HeatBin(center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon), intensity: intensity))
        }
        self.heatMapBins = realBins
        
        if esquinasUsuario.count == 3 {
            generarMapaVirtualCalibrado(puntos: rutaCoordenadasRaw, esquinas: esquinasUsuario)
        } else {
            generarMapaVirtualAutomatico(puntos: rutaCoordenadasRaw)
        }
    }
    
    private func generarMapaVirtualCalibrado(puntos: [CLLocationCoordinate2D], esquinas: [CLLocationCoordinate2D]) {
        let pTL = MKMapPoint(esquinas[0])
        let pTR = MKMapPoint(esquinas[1])
        let pBL = MKMapPoint(esquinas[2])
        
        let vectorU = (x: pTR.x - pTL.x, y: pTR.y - pTL.y)
        let lenU_sq = vectorU.x * vectorU.x + vectorU.y * vectorU.y
        
        let vectorV = (x: pBL.x - pTL.x, y: pBL.y - pTL.y)
        let lenV_sq = vectorV.x * vectorV.x + vectorV.y * vectorV.y
        
        var virtualGrid: [String: Int] = [:]
        var maxCount = 0
        
        for coord in puntos {
            let p = MKMapPoint(coord)
            let vecP = (x: p.x - pTL.x, y: p.y - pTL.y)
            
            let projU = (vecP.x * vectorU.x + vecP.y * vectorU.y) / lenU_sq
            let projV = (vecP.x * vectorV.x + vecP.y * vectorV.y) / lenV_sq
            
            if projU >= -0.1 && projU <= 1.1 && projV >= -0.1 && projV <= 1.1 {
                let cellX = Int(projU * 40)
                let cellY = Int(projV * 60)
                let key = "\(cellX)-\(cellY)"
                
                let c = (virtualGrid[key] ?? 0) + 1
                virtualGrid[key] = c
                maxCount = max(maxCount, c)
            }
        }
        
        let saturacion = max(Double(maxCount) * 0.30, 2.0)
        var bins: [VirtualHeatBin] = []
        
        for (key, count) in virtualGrid {
            let parts = key.split(separator: "-")
            if let cx = Int(parts[0]), let cy = Int(parts[1]) {
                let x = (Double(cx) + 0.5) / 40.0
                let y = (Double(cy) + 0.5) / 60.0
                let intensity = min(Double(count) / saturacion, 1.0)
                bins.append(VirtualHeatBin(x: x, y: y, intensity: intensity))
            }
        }
        self.virtualHeatBins = bins
    }
    
    private func generarMapaVirtualAutomatico(puntos: [CLLocationCoordinate2D]) {
        let puntosPlanos = puntos.map { MKMapPoint($0) }
        let centroX = puntosPlanos.map { $0.x }.reduce(0, +) / Double(puntosPlanos.count)
        let centroY = puntosPlanos.map { $0.y }.reduce(0, +) / Double(puntosPlanos.count)
        let centro = MKMapPoint(x: centroX, y: centroY)
        
        let anguloRotacion = calcularRotacionOptima(puntos: puntosPlanos, centro: centro)
        let puntosRotados = puntosPlanos.map { rotarPunto($0, centro: centro, angulo: anguloRotacion) }
        
        var minX = Double.greatestFiniteMagnitude, maxX = -Double.greatestFiniteMagnitude
        var minY = Double.greatestFiniteMagnitude, maxY = -Double.greatestFiniteMagnitude
        
        for p in puntosRotados {
            if p.x < minX { minX = p.x }
            if p.x > maxX { maxX = p.x }
            if p.y < minY { minY = p.y }
            if p.y > maxY { maxY = p.y }
        }
        
        let width = maxX - minX
        let height = maxY - minY
        let esHorizontal = width > height
        
        var virtualGrid: [String: Int] = [:]
        var maxCount = 0
        
        for p in puntosRotados {
            var normX = (p.x - minX) / width
            var normY = (p.y - minY) / height
            
            if esHorizontal {
                let temp = normX; normX = normY; normY = 1.0 - temp
            } else {
                normY = 1.0 - normY
            }
            
            let cellX = Int(normX * 40)
            let cellY = Int(normY * 60)
            let key = "\(cellX)-\(cellY)"
            let c = (virtualGrid[key] ?? 0) + 1
            virtualGrid[key] = c
            maxCount = max(maxCount, c)
        }
        
        let saturacion = max(Double(maxCount) * 0.30, 2.0)
        var bins: [VirtualHeatBin] = []
        for (key, count) in virtualGrid {
            let parts = key.split(separator: "-")
            if let cx = Int(parts[0]), let cy = Int(parts[1]) {
                let x = (Double(cx) + 0.5) / 40.0
                let y = (Double(cy) + 0.5) / 60.0
                let intensity = min(Double(count) / saturacion, 1.0)
                bins.append(VirtualHeatBin(x: x, y: y, intensity: intensity))
            }
        }
        self.virtualHeatBins = bins
    }
    
    private func calcularRotacionOptima(puntos: [MKMapPoint], centro: MKMapPoint) -> Double {
        var num: Double = 0, den: Double = 0
        for p in puntos {
            let dx = p.x - centro.x; let dy = p.y - centro.y
            num += 2 * dx * dy
            den += (dx * dx) - (dy * dy)
        }
        return 0.5 * atan2(den, num)
    }
    
    private func rotarPunto(_ p: MKMapPoint, centro: MKMapPoint, angulo: Double) -> MKMapPoint {
        let dx = p.x - centro.x; let dy = p.y - centro.y
        let xRot = dx * cos(angulo) - dy * sin(angulo)
        let yRot = dx * sin(angulo) + dy * cos(angulo)
        return MKMapPoint(x: centro.x + xRot, y: centro.y + yRot)
    }
    
    func finalizarCarga() { self.datosDisponibles = true; self.cargando = false }
    
    func formatearDuracion(_ duracion: TimeInterval) -> String {
        let f = DateComponentsFormatter(); f.allowedUnits = [.hour, .minute, .second]; f.unitsStyle = .abbreviated
        return f.string(from: duracion) ?? ""
    }
}

// MARK: - Components

struct CalibradorCampoView: View {
    @Environment(\.dismiss) var dismiss
    
    let rutaGPS: [CLLocationCoordinate2D]
    var alTerminar: ([CLLocationCoordinate2D]) -> Void
    
    @State private var esquinas: [CLLocationCoordinate2D] = []
    @State private var position: MapCameraPosition = .automatic
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Group {
                    if esquinas.isEmpty {
                        Text("1. Mueve el mapa hasta centrar la\n**Esquina Superior Izquierda**")
                    } else if esquinas.count == 1 {
                        Text("2. Ahora centra la\n**Esquina Superior Derecha**")
                    } else if esquinas.count == 2 {
                        Text("3. Finalmente, centra la\n**Esquina Inferior Izquierda**")
                    } else {
                        Text("¡Campo definido! Pulsa Guardar.")
                            .foregroundStyle(.green)
                    }
                }
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .padding()
                .frame(maxWidth: .infinity)
                .background(.regularMaterial)
                
                GeometryReader { geo in
                    MapReader { proxy in
                        ZStack {
                            Map(position: $position) {
                                if !rutaGPS.isEmpty {
                                    MapPolyline(coordinates: rutaGPS)
                                        .stroke(.blue.opacity(0.3), lineWidth: 4)
                                }
                                
                                ForEach(0..<esquinas.count, id: \.self) { i in
                                    Annotation("P\(i+1)", coordinate: esquinas[i]) {
                                        Image(systemName: "\(i+1).circle.fill")
                                            .font(.title)
                                            .foregroundStyle(.red)
                                            .background(.white)
                                            .clipShape(Circle())
                                            .shadow(radius: 2)
                                    }
                                }
                                
                                if esquinas.count == 3 {
                                    MapPolygon(coordinates: calcularRectangulo(p1: esquinas[0], p2: esquinas[1], p3: esquinas[2]))
                                        .foregroundStyle(.green.opacity(0.3))
                                        .stroke(.green, lineWidth: 2)
                                }
                            }
                            .mapStyle(.imagery(elevation: .realistic))
                            
                            if esquinas.count < 3 {
                                ZStack {
                                    Circle()
                                        .stroke(.white, lineWidth: 2)
                                        .shadow(radius: 4)
                                    Image(systemName: "plus")
                                        .font(.largeTitle)
                                        .foregroundStyle(.white)
                                        .shadow(radius: 4)
                                }
                                .frame(width: 50, height: 50)
                            }
                            
                            VStack {
                                Spacer()
                                
                                if esquinas.count < 3 {
                                    Button {
                                        let centroPantalla = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
                                        
                                        if let coordenada = proxy.convert(centroPantalla, from: .local) {
                                            let generator = UIImpactFeedbackGenerator(style: .medium)
                                            generator.impactOccurred()
                                            
                                            withAnimation {
                                                esquinas.append(coordenada)
                                            }
                                        }
                                    } label: {
                                        HStack {
                                            Image(systemName: "target")
                                            Text("Fijar Punto \(esquinas.count + 1)")
                                        }
                                        .font(.headline)
                                        .foregroundStyle(.white)
                                        .padding(.horizontal, 24)
                                        .padding(.vertical, 16)
                                        .background(Color.blue)
                                        .clipShape(Capsule())
                                        .shadow(radius: 10)
                                    }
                                    .padding(.bottom, 20)
                                }
                            }
                            
                            if !esquinas.isEmpty {
                                VStack {
                                    HStack {
                                        Button {
                                            _ = esquinas.popLast()
                                        } label: {
                                            Label("Deshacer", systemImage: "arrow.uturn.backward")
                                                .font(.caption)
                                                .padding(8)
                                                .background(.thinMaterial)
                                                .cornerRadius(8)
                                        }
                                        .padding(.leading)
                                        Spacer()
                                    }
                                    .padding(.top, 10)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Calibrar Campo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        if esquinas.count == 3 {
                            alTerminar(esquinas)
                            dismiss()
                        }
                    }
                    .disabled(esquinas.count != 3)
                }
            }
        }
    }
    
    func calcularRectangulo(p1: CLLocationCoordinate2D, p2: CLLocationCoordinate2D, p3: CLLocationCoordinate2D) -> [CLLocationCoordinate2D] {
        let mp1 = MKMapPoint(p1)
        let mp2 = MKMapPoint(p2)
        let mp3 = MKMapPoint(p3)
        
        let vecX = mp2.x - mp1.x
        let vecY = mp2.y - mp1.y
        
        let mp4 = MKMapPoint(x: mp3.x + vecX, y: mp3.y + vecY)
        return [p1, p2, mp4.coordinate, p3]
    }
}

struct DatoMetricView: View {
    let titulo: String; let valor: String; let icono: String; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack { Image(systemName: icono).foregroundStyle(color); Text(titulo).font(.caption).foregroundStyle(.secondary) }
            Text(valor).font(.headline).bold().monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding()
        .background(Color(UIColor.secondarySystemGroupedBackground)).cornerRadius(12).shadow(color: .black.opacity(0.03), radius: 3, x: 0, y: 1)
    }
}

struct ImagenEscudo: View {
    let data: Data?; let size: CGFloat
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: size, height: size).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
        } else {
            Circle().fill(Color.gray.opacity(0.1)).frame(width: size, height: size).overlay(Image(systemName: "shield.fill").font(.system(size: size * 0.5)).foregroundStyle(.gray.opacity(0.5)))
        }
    }
}
