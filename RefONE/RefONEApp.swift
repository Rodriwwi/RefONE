import SwiftUI
import SwiftData

@main
struct RefONEApp: App {
    // Lifecycle & Services Init
    init() {
        _ = GestorConectividad.shared
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                // MARK: Tab 1 - Dashboard
                InicioView()
                    .tabItem {
                        Label("Inicio", systemImage: "house.fill")
                    }
                
                // MARK: Tab 2 - Matches
                NavigationStack {
                    ListaPartidosView()
                }
                .tabItem {
                    Label("Partidos", systemImage: "soccerball")
                }
                
                // MARK: Tab 3 - Analytics
                EstadisticasView()
                    .tabItem {
                        Label("Estadísticas", systemImage: "chart.bar.xaxis")
                    }
                
                // MARK: Tab 4 - Settings
                ConfiguracionView()
                    .tabItem {
                        Label("Configuración", systemImage: "gearshape.fill")
                    }
            }
            .tint(Color(hex: "#FF5A36"))
        }
        // Data Container Injection
        .modelContainer(for: [
            Categoria.self,
            Equipo.self,
            Estadio.self,
            Partido.self
        ])
    }
}
