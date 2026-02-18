import SwiftUI
import SwiftData

struct ConfiguracionView: View {
    // Persistencia local - Perfil
    @AppStorage("nombreUsuario") private var nombreUsuario: String = ""
    
    // Persistencia local - Notificaciones (Guardamos como texto: "10,60,1440")
    @AppStorage("recordatoriosPartido") private var recordatoriosGuardados: String = ""
    
    // Persistencia local - Zonas Cardíacas
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    @AppStorage("limiteZ1") private var limiteZ1: Double = 0.60
    @AppStorage("limiteZ2") private var limiteZ2: Double = 0.70
    @AppStorage("limiteZ3") private var limiteZ3: Double = 0.80
    @AppStorage("limiteZ4") private var limiteZ4: Double = 0.90
    
    // Consultamos los partidos futuros para reprogramar las alarmas al instante si el usuario cambia algo
    @Query(filter: #Predicate<Partido> { !$0.finalizado }) private var partidosFuturos: [Partido]
    
    // Opciones disponibles (Etiqueta, Minutos)
    let opcionesRecordatorio: [(label: String, value: Int)] = [
        ("10 minutos antes", 10),
        ("Media hora antes", 30),
        ("1 hora antes", 60),
        ("2 horas antes", 120),
        ("1 día antes", 1440),
        ("2 días antes", 2880),
        ("1 semana antes", 10080)
    ]
    
    // Propiedad solo lectura para convertir el String guardado en Array
    var recordatoriosSeleccionados: [Int] {
        if recordatoriosGuardados.isEmpty { return [] }
        return recordatoriosGuardados.split(separator: ",").compactMap { Int($0) }
    }
    
    // Genera el texto resumen para cuando el desplegable está cerrado
    var resumenNotificaciones: String {
        let cantidad = recordatoriosSeleccionados.count
        if cantidad == 0 { return "Desactivados" }
        else if cantidad == 1 { return "1 aviso" }
        else { return "\(cantidad) avisos" }
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("Perfil") {
                    HStack {
                        Text("Nombre:")
                        TextField("Tu nombre", text: $nombreUsuario)
                            .multilineTextAlignment(.trailing)
                    }
                }
                
                // MARK: - NOTIFICACIONES (DESPLEGABLE)
                Section("Notificaciones") {
                    DisclosureGroup {
                        ForEach(opcionesRecordatorio, id: \.value) { opcion in
                            Toggle(opcion.label, isOn: Binding(
                                get: { recordatoriosSeleccionados.contains(opcion.value) },
                                set: { activado in
                                    var actuales = recordatoriosSeleccionados
                                    if activado {
                                        actuales.append(opcion.value)
                                    } else {
                                        actuales.removeAll(where: { $0 == opcion.value })
                                    }
                                    
                                    // Guardamos directamente en AppStorage
                                    recordatoriosGuardados = actuales.map { String($0) }.joined(separator: ",")
                                    
                                    // Actualizamos todas las alarmas
                                    GestorNotificaciones.shared.actualizarTodas(partidos: partidosFuturos, minutos: actuales)
                                }
                            ))
                            .tint(.orange)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.orange)
                            Text("Notificaciones de Partido")
                                .foregroundStyle(.primary)
                            Spacer()
                            // Mostramos el resumen cuando está cerrado
                            Text(resumenNotificaciones)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                
                // MARK: - SALUD Y RENDIMIENTO
                Section("Salud y Rendimiento") {
                    VStack(alignment: .leading) {
                        Text("Frecuencia Cardíaca Máxima (FC Max)")
                            .font(.caption).foregroundStyle(.secondary)
                        HStack {
                            Text("\(Int(fcMax)) bpm")
                                .font(.title3).bold().foregroundStyle(.red)
                            Slider(value: $fcMax, in: 150...220, step: 1)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    DisclosureGroup("Configurar Intervalos de Zonas") {
                        VStack(spacing: 15) {
                            Text("Ajusta el límite superior de cada zona (% de FC Max).")
                                .font(.caption2).foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            ControlZona(nombre: "Zona 1", valor: $limiteZ1, color: .blue, rango: 0.5...limiteZ2)
                            ControlZona(nombre: "Zona 2", valor: $limiteZ2, color: .green, rango: limiteZ1...limiteZ3)
                            ControlZona(nombre: "Zona 3", valor: $limiteZ3, color: .yellow, rango: limiteZ2...limiteZ4)
                            ControlZona(nombre: "Zona 4", valor: $limiteZ4, color: .orange, rango: limiteZ3...0.99)
                            
                            HStack {
                                Circle().fill(Color.red).frame(width: 8, height: 8)
                                Text("Zona 5")
                                Spacer()
                                Text("> \(Int(fcMax * limiteZ4)) bpm")
                            }
                            .font(.caption).bold()
                        }
                        .padding(.top, 10)
                    }
                }
                
                // MARK: - BASE DE DATOS
                Section("Base de Datos") {
                    NavigationLink(destination: ListaCategoriasView()) {
                        Label("Categorías y Dietas", systemImage: "eurosign.circle")
                    }
                    NavigationLink(destination: ListaEquiposView()) {
                        Label("Equipos", systemImage: "tshirt")
                    }
                    NavigationLink(destination: ListaEstadiosView()) {
                        Label("Campos", systemImage: "sportscourt")
                    }
                }
                
                Section("Acerca de") {
                    HStack {
                        Label("Versión", systemImage: "info.circle")
                        Spacer()
                        Text("0.1.6")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("Configuración")
            .onAppear {
                // Pedimos permisos de notificación al entrar a esta vista
                GestorNotificaciones.shared.solicitarPermisos()
            }
        }
    }
}

// MARK: - SUBVISTAS

struct ControlZona: View {
    let nombre: String
    @Binding var valor: Double
    let color: Color
    let rango: ClosedRange<Double>
    @AppStorage("fcMax") private var fcMax: Double = 190.0
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Circle().fill(color).frame(width: 8, height: 8)
                Text(nombre).font(.caption).bold()
                Spacer()
                Text("\(Int(valor * 100))%").font(.caption).foregroundStyle(.secondary)
                Text("(\(Int(fcMax * valor)) bpm)").font(.caption).bold().monospacedDigit()
            }
            Slider(value: $valor, in: rango)
        }
    }
}
