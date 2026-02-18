import SwiftUI
import SwiftData

struct FormularioPartidoView: View {
    // Contexto y Navegación
    @Environment(\.modelContext) private var contexto
    @Environment(\.dismiss) private var cerrar
    
    // Consultas de Persistencia
    @Query(sort: \Equipo.nombre) private var equipos: [Equipo]
    @Query(sort: \Categoria.nombre) private var categorias: [Categoria]
    
    // Estado del Formulario
    @State private var local: Equipo?
    @State private var visitante: Equipo?
    @State private var categoria: Categoria?
    @State private var fecha: Date = Date()
    @State private var desplazamiento: Double = 0.0
    
    // Configuración Visual
    @State private var colorLocalOverride: Color = .black
    @State private var colorVisitanteOverride: Color = .white
    @State private var usarColoresPersonalizados = false
    
    // Lógica de Negocio
    @State private var rol: RolArbitro = .principal
    
    var body: some View {
        NavigationStack {
            Form {
                // MARK: Configuración del Encuentro
                Section("Detalles del Encuentro") {
                    Picker("Categoría", selection: $categoria) {
                        Text("Seleccionar").tag(nil as Categoria?)
                        ForEach(categorias) { cat in
                            Text(cat.nombre).tag(cat as Categoria?)
                        }
                    }
                    .onChange(of: categoria) {
                        if let cat = categoria, !cat.permiteAsistente {
                            rol = .principal
                        }
                    }
                    
                    DatePicker("Fecha y Hora", selection: $fecha)
                    
                    if let cat = categoria, cat.permiteAsistente {
                        Picker("Tu Rol", selection: $rol) {
                            ForEach(RolArbitro.allCases) { role in
                                Text(role.rawValue).tag(role)
                            }
                        }
                        .pickerStyle(.segmented)
                    } else {
                        HStack {
                            Text("Actuando de:")
                            Spacer()
                            Text("Principal")
                                .foregroundStyle(.secondary)
                                .italic()
                        }
                    }
                }
                
                // MARK: Selección de Equipos
                Section("Equipos") {
                    Picker("Local", selection: $local) {
                        Text("Seleccionar").tag(nil as Equipo?)
                        ForEach(equipos) { equipo in
                            Text(equipo.nombre).tag(equipo as Equipo?)
                        }
                    }
                    
                    Picker("Visitante", selection: $visitante) {
                        Text("Seleccionar").tag(nil as Equipo?)
                        ForEach(equipos) { equipo in
                            if equipo != local {
                                Text(equipo.nombre).tag(equipo as Equipo?)
                            }
                        }
                    }
                }
                
                // MARK: Datos Económicos
                Section("Dietas") {
                    HStack {
                        Text("Desplazamiento: ")
                        TextField("0.0", value: $desplazamiento, format: .currency(code: "EUR"))
                            .keyboardType(.decimalPad)
                    }
                }
                
                // MARK: Personalización Visual
                Section("Color de las equipaciones") {
                    Toggle("Personalizar", isOn: $usarColoresPersonalizados)
                    
                    if usarColoresPersonalizados {
                        ColorPicker("Color Local", selection: $colorLocalOverride)
                        ColorPicker("Color Visitante", selection: $colorVisitanteOverride)
                    }
                }
                
                // MARK: Live Preview
                Section {
                    VStack(spacing: 15) {
                        Text("VISTA PREVIA")
                            .font(.caption)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                        
                        HStack(alignment: .center, spacing: 20) {
                            // Renderizado Local
                            VStack {
                                ImagenEscudoGrande(data: local?.escudoData)
                                Rectangle()
                                    .fill(local?.colorHex.toColor() ?? .gray)
                                    .frame(height: 4)
                                    .frame(maxWidth: 60)
                            }
                            
                            Text("vs")
                                .font(.title)
                                .italic()
                                .foregroundStyle(.secondary)
                            
                            // Renderizado Visitante
                            VStack {
                                ImagenEscudoGrande(data: visitante?.escudoData)
                                Rectangle()
                                    .fill(visitante?.colorVisitanteHex.toColor() ?? .gray)
                                    .frame(height: 4)
                                    .frame(maxWidth: 60)
                            }
                        }
                        
                        Divider()
                        
                        VStack(spacing: 5) {
                            Text(categoria?.nombre ?? "Categoría")
                                .font(.headline)
                            
                            Text(rol.rawValue.uppercased())
                                .font(.caption2)
                                .bold()
                                .padding(4)
                                .background(rol == .principal ? Color.indigo.opacity(0.2) : Color.orange.opacity(0.2))
                                .foregroundStyle(rol == .principal ? .indigo : .orange)
                                .cornerRadius(4)
                            
                            HStack {
                                Image(systemName: "sportscourt")
                                Text(local?.estadio?.nombre ?? "Estadio Local")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            
                            Text(fecha, format: .dateTime.day().month().year().hour().minute())
                                .font(.footnote)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                } header: {
                    Text("Resumen")
                }
            }
            .navigationTitle("Nuevo Partido")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { cerrar() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { guardar() }
                        .disabled(local == nil || visitante == nil || categoria == nil)
                }
            }
        }
    }
    
    // MARK: - Persistencia y Sincronización
    
    private func guardar() {
        // Validación de nulabilidad
        guard let cat = categoria, let eqLocal = local, let eqVisitante = visitante else { return }
        
        let esPrincipal = (rol == .principal)
        
        // Instancia del modelo persistente
        let nuevoPartido = Partido(
            fecha: fecha,
            equipoLocal: eqLocal,
            equipoVisitante: eqVisitante,
            categoria: cat,
            actuadoComoPrincipal: esPrincipal,
            costeDesplazamiento: desplazamiento
        )
        
        // Aplicación de overrides visuales
        if usarColoresPersonalizados {
            nuevoPartido.colorLocalHexPartido = colorLocalOverride.toHex() ?? "#000000"
            nuevoPartido.colorVisitanteHexPartido = colorVisitanteOverride.toHex() ?? "#FFFFFF"
        }
        
        contexto.insert(nuevoPartido)
        
        // Obtenemos los minutos seleccionados en la configuración
        let opcionesGuardadas = UserDefaults.standard.string(forKey: "recordatoriosPartido") ?? ""
        let minutos = opcionesGuardadas.split(separator: ",").compactMap { Int($0) }

        // Programamos la notificación para este partido concreto
        GestorNotificaciones.shared.programarNotificaciones(para: nuevoPartido, minutosAntes: minutos)
        
        do {
            try contexto.save()
            sincronizarConWatch()
            cerrar()
        } catch {
            print("Error critico guardando partido: \(error)")
        }
    }
    
    private func sincronizarConWatch() {
        do {
            let descriptor = FetchDescriptor<Partido>(
                predicate: #Predicate { $0.finalizado == false },
                sortBy: [SortDescriptor(\.fecha)]
            )
            let partidosPendientes = try contexto.fetch(descriptor)
            
            // Mapping de DTO para WatchConnectivity
            let listaParaReloj = partidosPendientes.map { p in
                let colorL = !p.colorLocalHexPartido.isEmpty ? p.colorLocalHexPartido : (p.equipoLocal?.colorHex ?? "#000000")
                let colorV = !p.colorVisitanteHexPartido.isEmpty ? p.colorVisitanteHexPartido : (p.equipoVisitante?.colorVisitanteHex ?? "#FFFFFF")
                
                return PartidoReloj(
                    id: p.id,
                    equipoLocal: p.equipoLocal?.nombre ?? "Local",
                    acronimoLocal: p.equipoLocal?.acronimo ?? "LOC",
                    colorLocalHex: colorL,
                    localEscudoData: p.equipoLocal?.escudoData,
                    
                    equipoVisitante: p.equipoVisitante?.nombre ?? "Visitante",
                    acronimoVisitante: p.equipoVisitante?.acronimo ?? "VIS",
                    colorVisitanteHex: colorV,
                    visitanteEscudoData: p.equipoVisitante?.escudoData,
                    
                    estadio: p.equipoLocal?.estadio?.nombre ?? "Estadio",
                    fecha: p.fecha,
                    categoria: p.categoria?.nombre ?? "General",
                    
                    duracionParteMinutos: p.categoria?.duracionParteMinutos ?? 45,
                    duracionDescansoMinutos: p.categoria?.duracionDescansoMinutos ?? 15,
                    
                    workoutID: p.workoutID
                )
            }
            
            GestorConectividad.shared.enviarPartidosAlReloj(listaParaReloj)
            
        } catch {
            print("Error en sincronizacion WatchConnectivity: \(error)")
        }
    }
    
    // MARK: - Subvistas
    
    struct ImagenEscudoGrande: View {
        let data: Data?
        
        var body: some View {
            if let data = data, let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 70, height: 70)
                    .clipShape(Circle())
                    .shadow(radius: 3)
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.1))
                    .frame(width: 70, height: 70)
                    .overlay(
                        Image(systemName: "shield.fill")
                            .font(.largeTitle)
                            .foregroundStyle(.gray.opacity(0.3))
                    )
            }
        }
    }
}
