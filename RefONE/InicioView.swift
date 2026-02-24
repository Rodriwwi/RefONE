import SwiftUI
import SwiftData

struct InicioView: View {
    @AppStorage("nombreUsuario") private var nombreUsuario: String = "Árbitro"
    @Query(sort: \Partido.fecha, order: .forward) private var partidos: [Partido]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    
                    // Header
                    HStack(alignment: .center) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Hola, \(nombreUsuario)")
                                .font(.system(size: 34, weight: .bold, design: .rounded))
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            
                            Text("Bienvenido a RefONE")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image("LogoApp")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 110)
                    }
                    .padding(.top, 20)
                    
                    // Resumen Mensual
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Text("Este mes")
                                .font(.headline)
                                .foregroundStyle(.white)
                            Spacer()
                            Image(systemName: "calendar")
                                .foregroundStyle(.white.opacity(0.8))
                        }
                        
                        HStack(spacing: 20) {
                            DatoResumenView(valor: "\(partidosMes.count)", etiqueta: "Partidos")
                            Divider().background(.white.opacity(0.5))
                            DatoResumenView(valor: "\(golesMes)", etiqueta: "Goles")
                            Divider().background(.white.opacity(0.5))
                            DatoResumenView(valor: String(format: "%.0f€", gananciasMes), etiqueta: "Ganado")
                        }
                        .padding(.top, 5)
                    }
                    .padding(20)
                    .background(LinearGradient(colors: [.orange, .red], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .cornerRadius(20)
                    .shadow(color: .orange.opacity(0.3), radius: 10, x: 0, y: 5)
                    
                    // Próximos Partidos
                    VStack(alignment: .leading, spacing: 15) {
                        Text("Próximos Partidos")
                            .font(.title2)
                            .bold()
                        
                        if proximosPartidos.isEmpty {
                            HStack {
                                Spacer()
                                VStack(spacing: 10) {
                                    Image(systemName: "calendar.badge.exclamationmark")
                                        .font(.largeTitle)
                                        .foregroundStyle(.gray)
                                    Text("No tienes partidos programados")
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 30)
                                Spacer()
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(12)
                        } else {
                            ForEach(proximosPartidos.prefix(3)) { partido in
                                NavigationLink(destination: VistaPreviaPartido(partido: partido)) {
                                    CeldaResumenInicio(partido: partido)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 30)
            }
            .navigationBarHidden(true)
            .background(FondoGridMinimalista())
        }
    }
}

// MARK: - Lógica y Extensiones
extension InicioView {
    var partidosMes: [Partido] {
        let now = Date()
        return partidos.filter { partido in
            Calendar.current.isDate(partido.fecha, equalTo: now, toGranularity: .month) && partido.finalizado
        }
    }
    
    var golesMes: Int {
        partidosMes.reduce(0) { $0 + ($1.golesLocal + $1.golesVisitante) }
    }
    
    var gananciasMes: Double {
        partidosMes.reduce(0.0) { total, p in
            let tarifa = p.actuadoComoPrincipal ? (p.categoria?.tarifaPrincipal ?? 0) : (p.categoria?.tarifaAsistente ?? 0)
            return total + tarifa + p.costeDesplazamiento
        }
    }
    
    var proximosPartidos: [Partido] {
        partidos.filter { !$0.finalizado && $0.fecha >= Date().addingTimeInterval(-3600) }
    }
}

// MARK: - Subvistas

struct DatoResumenView: View {
    let valor: String; let etiqueta: String
    var body: some View {
        VStack(alignment: .leading) {
            Text(valor).font(.system(size: 24, weight: .heavy, design: .rounded)).foregroundStyle(.white)
            Text(etiqueta).font(.caption).foregroundStyle(.white.opacity(0.9)).fontWeight(.medium)
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - CELDA REDISEÑADA

struct CeldaResumenInicio: View {
    let partido: Partido
    
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 10) {
                
                // Cabecera: Categoría y Estadio
                HStack(spacing: 6) {
                    Text(partido.categoria?.nombre.uppercased() ?? "AMISTOSO")
                        .font(.caption2)
                        .bold()
                        .foregroundStyle(.orange)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.orange.opacity(0.15))
                        .clipShape(Capsule())
                    
                    HStack(spacing: 2) {
                        Image(systemName: "mappin.and.ellipse")
                        Text(partido.equipoLocal?.estadio?.nombre ?? "Sin campo")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                }
                
                // Bloque de Equipos (Con color y escudo integrados)
                VStack(alignment: .leading, spacing: 6) {
                    // Equipo Local
                    HStack(spacing: 8) {
                        IndicadorColorEquipacion(hex: partido.equipoLocal?.colorHex ?? "#808080")
                        ImagenEscudoMini(data: partido.equipoLocal?.escudoData)
                        Text(partido.equipoLocal?.nombre ?? "Local")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                    
                    // Equipo Visitante
                    HStack(spacing: 8) {
                        IndicadorColorEquipacion(hex: partido.equipoVisitante?.colorVisitanteHex ?? "#F0F0F0")
                        ImagenEscudoMini(data: partido.equipoVisitante?.escudoData)
                        Text(partido.equipoVisitante?.nombre ?? "Visitante")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .lineLimit(1)
                    }
                }
            }
            
            Spacer(minLength: 0)
            
            // Bloque de Fecha y Hora
            VStack(alignment: .center, spacing: 2) {
                Text(partido.fecha.formatted(.dateTime.day()))
                    .font(.title3)
                    .bold()
                Text(partido.fecha.formatted(.dateTime.month(.abbreviated)))
                    .font(.caption2)
                    .textCase(.uppercase)
                    .foregroundStyle(.red)
                
                Text(partido.fecha.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .padding(.top, 4)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.gray.opacity(0.08))
            .cornerRadius(10)
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.04), radius: 5, x: 0, y: 2)
    }
}

// MARK: - Componentes Pequeños para la Celda

// Nuevo: Indicador de color circular simple
struct IndicadorColorEquipacion: View {
    let hex: String
    var body: some View {
        Circle()
            .fill(hex.toColor())
            .frame(width: 12, height: 12)
            .overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
}

struct ImagenEscudoMini: View {
    let data: Data?
    var body: some View {
        if let data = data, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage).resizable().scaledToFill().frame(width: 20, height: 20).clipShape(Circle()).overlay(Circle().stroke(Color.gray.opacity(0.2), lineWidth: 0.5))
        } else {
            Circle().fill(Color.gray.opacity(0.15)).frame(width: 20, height: 20).overlay(Image(systemName: "shield.fill").font(.system(size: 9)).foregroundStyle(.gray.opacity(0.5)))
        }
    }
}

struct FondoGridMinimalista: View {
    var body: some View {
        ZStack {
            Color(UIColor.systemGroupedBackground)
            GeometryReader { geo in
                ForEach(0..<8) { i in
                    Rectangle().fill(LinearGradient(colors: [.orange.opacity(0.02), .orange.opacity(0.05), .orange.opacity(0.02)], startPoint: .top, endPoint: .bottom))
                        .frame(width: 1).offset(x: CGFloat(i) * (geo.size.width / 7))
                }
                ForEach(0..<12) { i in
                    Rectangle().fill(LinearGradient(colors: [.orange.opacity(0.02), .orange.opacity(0.05), .orange.opacity(0.02)], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 1).offset(y: CGFloat(i) * (geo.size.height / 11))
                }
            }
            LinearGradient(colors: [.orange.opacity(0.08), .clear], startPoint: .topTrailing, endPoint: .center)
            LinearGradient(colors: [.clear, .red.opacity(0.06)], startPoint: .center, endPoint: .bottomLeading)
            VStack {
                HStack { Circle().fill(Color.orange.opacity(0.15)).frame(width: 4, height: 4).padding(.top, 100).padding(.leading, 30); Spacer(); Circle().fill(Color.orange.opacity(0.12)).frame(width: 3, height: 3).padding(.top, 150).padding(.trailing, 50) }
                Spacer()
                HStack { Circle().fill(Color.red.opacity(0.10)).frame(width: 3, height: 3).padding(.bottom, 200).padding(.leading, 80); Spacer(); Circle().fill(Color.orange.opacity(0.14)).frame(width: 4, height: 4).padding(.bottom, 150).padding(.trailing, 40) }
            }
        }
        .ignoresSafeArea()
    }
}
