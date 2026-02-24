import SwiftUI
import SwiftData
import Charts

// MARK: - Enums & Modelos Auxiliares

enum FiltroTiempo: String, CaseIterable, Identifiable {
    case mesActual = "Mes"
    case esteAno = "Año"
    case total = "Total"
    case personalizado = "Rango..."
    
    var id: String { self.rawValue }
}

// MARK: - Vista Principal

struct EstadisticasView: View {
    // Acceso a datos
    @Query(sort: \Partido.fecha, order: .reverse) private var todosLosPartidos: [Partido]
    
    // Estado de UI
    @State private var filtroSeleccionado: FiltroTiempo = .mesActual
    @State private var fechaInicio: Date = Date().addingTimeInterval(-30*24*60*60)
    @State private var fechaFin: Date = Date()
    
    // Constantes de diseño
    private let cDinero = Color.green
    private let cStats = Color.blue
    private let cRolPrincipal = Color(hex: "#FF5A36")
    private let cRolAsistente = Color(hex: "#1F73FF")
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    
                    // MARK: Filtros
                    VStack(spacing: 8) {
                        Picker("Filtro", selection: $filtroSeleccionado.animation()) {
                            ForEach(FiltroTiempo.allCases) { filtro in
                                Text(filtro.rawValue).tag(filtro)
                            }
                        }
                        .pickerStyle(.segmented)
                        
                        if filtroSeleccionado == .personalizado {
                            HStack {
                                DatePicker("De", selection: $fechaInicio, displayedComponents: .date)
                                    .labelsHidden()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                DatePicker("A", selection: $fechaFin, displayedComponents: .date)
                                    .labelsHidden()
                            }
                            .padding(8)
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(8)
                        }
                        Text(textoRangoActual)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                    
                    // MARK: Estado Vacío vs Contenido
                    if partidosFiltrados.isEmpty {
                        ContentUnavailableView("Sin datos", systemImage: "chart.bar.xaxis", description: Text("No hay partidos finalizados en este periodo."))
                            .padding(.top, 40)
                    } else {
                        
                        // MARK: Header Financiero
                        VStack(spacing: 6) {
                            Text("INGRESOS ESTIMADOS")
                                .font(.caption2).fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .tracking(1)
                            
                            Text(formatoMoneda(totalGanado))
                                .font(.system(size: 48, weight: .black, design: .rounded))
                                .foregroundStyle(LinearGradient(
                                    colors: [cDinero, cDinero.opacity(0.6)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ))
                                .contentTransition(.numericText())
                            
                            HStack(spacing: 12) {
                                PillDato(texto: "\(formatoMoneda(promedioGanancia))/partido", icono: "tag.fill")
                                PillDato(texto: "\(formatoMoneda(gananciaPorMinuto))/min", icono: "clock.fill")
                            }
                        }
                        
                        // MARK: Distribución de Rol
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Distribución de Rol")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            // Barra de progreso custom
                            GeometryReader { geo in
                                HStack(spacing: 0) {
                                    if conteoPrincipal > 0 {
                                        Rectangle()
                                            .fill(cRolPrincipal.gradient)
                                            .frame(width: geo.size.width * (porcentajePrincipal / 100))
                                    }
                                    if conteoAsistente > 0 {
                                        Rectangle()
                                            .fill(cRolAsistente.gradient)
                                            .frame(width: geo.size.width * (porcentajeAsistente / 100))
                                    }
                                }
                            }
                            .frame(height: 12)
                            .clipShape(Capsule())
                            .padding(.horizontal)
                            
                            // Leyenda
                            HStack {
                                Label("\(conteoPrincipal) Principal (\(Int(porcentajePrincipal))%)", systemImage: "circle.fill")
                                    .foregroundStyle(cRolPrincipal)
                                Spacer()
                                Label("\(conteoAsistente) Asistente (\(Int(porcentajeAsistente))%)", systemImage: "circle.fill")
                                    .foregroundStyle(cRolAsistente)
                            }
                            .font(.caption).bold()
                            .padding(.horizontal)
                        }
                        
                        // MARK: KPI Grid (Físico/Técnico)
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Rendimiento")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                                TarjetaStat(valor: "\(partidosFiltrados.count)", titulo: "Partidos", icono: "whistle.fill", color: .blue)
                                TarjetaStat(valor: "\(totalGoles)", titulo: "Goles Totales", icono: "soccerball", color: .teal)
                                TarjetaStat(valor: formatoTiempo(minutosTotales), titulo: "Tiempo Arbitrado", icono: "stopwatch.fill", color: .orange)
                                TarjetaStat(valor: formatoDistancia(distanciaTotal), titulo: "Distancia (Est.)", icono: "figure.run", color: .pink)
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: Gráfica Mensual
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Vista Mensual")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            Chart {
                                ForEach(datosPorMes, id: \.mes) { dato in
                                    BarMark(
                                        x: .value("Mes", dato.mes, unit: .month),
                                        y: .value("Partidos", dato.cantidad)
                                    )
                                    .foregroundStyle(cStats.gradient)
                                    .cornerRadius(4)
                                }
                                RuleMark(y: .value("Media", Double(partidosFiltrados.count) / Double(max(1, datosPorMes.count))))
                                    .foregroundStyle(.gray.opacity(0.3))
                                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5]))
                            }
                            .chartXAxis {
                                AxisMarks(values: .stride(by: .month)) { _ in
                                    AxisValueLabel(format: .dateTime.month(.narrow))
                                }
                            }
                            .frame(height: 160)
                            .padding()
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                        
                        // MARK: Hábitos
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Hábitos")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            HStack(spacing: 12) {
                                TarjetaHabito(titulo: "Día Favorito", valor: diaMasActivo, icono: "calendar")
                                TarjetaHabito(titulo: "Horario", valor: momentoDelDiaFavorito, icono: "sun.max.fill")
                            }
                            .padding(.horizontal)
                        }
                        
                        // MARK: Curiosidades
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Curiosidades")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            VStack(spacing: 0) {
                                FilaRecord(titulo: "Partido con más goles", valor: partidoMasGoles, icono: "trophy.fill", color: .yellow)
                                Divider().padding(.leading, 50)
                                FilaRecord(titulo: "Equipo más frecuente", valor: equipoMasFrecuente, icono: "tshirt.fill", color: .purple)
                            }
                            .background(Color(UIColor.secondarySystemGroupedBackground))
                            .cornerRadius(16)
                            .padding(.horizontal)
                        }
                    }
                }
                .padding(.bottom, 50)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Estadísticas")
            .toolbar {
                if !partidosFiltrados.isEmpty {
                    ShareLink(item: generarResumenTexto()) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}

// MARK: - Lógica y Computados

extension EstadisticasView {
    
    // Filtrado
    var partidosFiltrados: [Partido] {
        let calendario = Calendar.current
        let ahora = Date()
        
        return todosLosPartidos.filter { partido in
            guard partido.finalizado else { return false }
            
            switch filtroSeleccionado {
            case .mesActual:
                return calendario.isDate(partido.fecha, equalTo: ahora, toGranularity: .month)
            case .esteAno:
                return calendario.isDate(partido.fecha, equalTo: ahora, toGranularity: .year)
            case .total:
                return true
            case .personalizado:
                let inicio = calendario.startOfDay(for: fechaInicio)
                let fin = calendario.date(bySettingHour: 23, minute: 59, second: 59, of: fechaFin) ?? fechaFin
                return partido.fecha >= inicio && partido.fecha <= fin
            }
        }
    }
    
    var textoRangoActual: String {
        switch filtroSeleccionado {
        case .mesActual: return "Mostrando mes actual"
        case .esteAno: return "Mostrando año actual"
        case .total: return "Histórico completo"
        case .personalizado: return "Rango personalizado"
        }
    }
    
    // Métricas Financieras
    var totalGanado: Double {
        partidosFiltrados.reduce(0) { total, p in
            let tarifa = p.actuadoComoPrincipal
                ? (p.categoria?.tarifaPrincipal ?? 0)
                : (p.categoria?.tarifaAsistente ?? 0)
            return total + tarifa + p.costeDesplazamiento
        }
    }
    
    var promedioGanancia: Double {
        guard !partidosFiltrados.isEmpty else { return 0 }
        return totalGanado / Double(partidosFiltrados.count)
    }
    
    var gananciaPorMinuto: Double {
        guard minutosTotales > 0 else { return 0 }
        return totalGanado / Double(minutosTotales)
    }
    
    // Métricas de Rol
    var conteoPrincipal: Int { partidosFiltrados.filter { $0.actuadoComoPrincipal }.count }
    var conteoAsistente: Int { partidosFiltrados.filter { !$0.actuadoComoPrincipal }.count }
    
    var porcentajePrincipal: Double {
        guard !partidosFiltrados.isEmpty else { return 0 }
        return (Double(conteoPrincipal) / Double(partidosFiltrados.count)) * 100
    }
    
    var porcentajeAsistente: Double {
        guard !partidosFiltrados.isEmpty else { return 0 }
        return (Double(conteoAsistente) / Double(partidosFiltrados.count)) * 100
    }
    
    // Métricas Físicas
    var totalGoles: Int {
        partidosFiltrados.reduce(0) { $0 + ($1.golesLocal + $1.golesVisitante) }
    }
    
    var minutosTotales: Int {
        partidosFiltrados.reduce(0) { total, p in
            // Fallback a 90 min (45x2) si no hay categoría definida
            let duracion = (p.categoria?.duracionParteMinutos ?? 45) * 2
            return total + duracion
        }
    }
    
    var distanciaTotal: Double {
        partidosFiltrados.reduce(0.0) { $0 + $1.distanciaRecorrida }
    }
    
    // Hábitos y Tendencias
    var momentoDelDiaFavorito: String {
        let manana = partidosFiltrados.filter { Calendar.current.component(.hour, from: $0.fecha) < 14 }.count
        return manana > (partidosFiltrados.count - manana) ? "Mañanas" : "Tardes"
    }
    
    var diaMasActivo: String {
        var counts = [Int: Int]()
        partidosFiltrados.forEach { counts[Calendar.current.component(.weekday, from: $0.fecha), default: 0] += 1 }
        
        guard let dia = counts.max(by: { $0.value < $1.value })?.key else { return "-" }
        return DateFormatter().weekdaySymbols[dia - 1].capitalized
    }
    
    var datosPorMes: [(mes: Date, cantidad: Int)] {
        let cal = Calendar.current
        var dict = [Date: Int]()
        
        partidosFiltrados.forEach {
            if let date = cal.date(from: cal.dateComponents([.year, .month], from: $0.fecha)) {
                dict[date, default: 0] += 1
            }
        }
        return dict.map { (mes: $0.key, cantidad: $0.value) }.sorted { $0.mes < $1.mes }
    }
    
    // Records
    var partidoMasGoles: String {
        guard let p = partidosFiltrados.max(by: { ($0.golesLocal + $0.golesVisitante) < ($1.golesLocal + $1.golesVisitante) }) else { return "-" }
        return "\(p.golesLocal + p.golesVisitante) Goles (\(p.equipoLocal?.acronimo ?? "") vs \(p.equipoVisitante?.acronimo ?? ""))"
    }
    
    var equipoMasFrecuente: String {
        var counts = [String: Int]()
        partidosFiltrados.forEach {
            counts[$0.equipoLocal?.nombre ?? "", default: 0] += 1
            counts[$0.equipoVisitante?.nombre ?? "", default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key ?? "-"
    }
    
    // Helpers de Formato
    func formatoMoneda(_ val: Double) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.locale = Locale.current
        return f.string(from: NSNumber(value: val)) ?? "\(val)€"
    }
    
    func formatoTiempo(_ minutos: Int) -> String {
        minutos < 60 ? "\(minutos) min" : "\(minutos / 60)h \(minutos % 60)m"
    }
    
    func formatoDistancia(_ metros: Double) -> String {
        String(format: "%.1f km", metros / 1000)
    }
    
    func generarResumenTexto() -> String {
        """
        RESUMEN RefONE - \(textoRangoActual)
        Total: \(formatoMoneda(totalGanado)) | \(partidosFiltrados.count) Partidos
        """
    }
}

// MARK: - Componentes Visuales

struct PillDato: View {
    let texto: String
    let icono: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icono)
            Text(texto)
        }
        .font(.caption2).fontWeight(.bold)
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color.green.opacity(0.1))
        .foregroundStyle(Color.green)
        .clipShape(Capsule())
    }
}

struct TarjetaStat: View {
    let valor: String
    let titulo: String
    let icono: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: icono)
                    .font(.headline)
                    .foregroundStyle(color)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(valor)
                    .font(.title3)
                    .fontWeight(.bold)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(titulo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
    }
}

struct TarjetaHabito: View {
    let titulo: String
    let valor: String
    let icono: String
    
    var body: some View {
        HStack {
            Image(systemName: icono)
                .font(.title2)
                .foregroundStyle(.gray.opacity(0.5))
            
            VStack(alignment: .leading) {
                Text(titulo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(valor)
                    .font(.subheadline)
                    .bold()
            }
            Spacer()
        }
        .padding()
        .background(Color(UIColor.secondarySystemGroupedBackground))
        .cornerRadius(12)
    }
}

struct FilaRecord: View {
    let titulo: String
    let valor: String
    let icono: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icono)
                .font(.subheadline)
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color)
                .clipShape(Circle())
            
            VStack(alignment: .leading) {
                Text(titulo)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(valor)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(12)
    }
}
