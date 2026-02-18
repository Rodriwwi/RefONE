import Foundation
import UserNotifications

class GestorNotificaciones {
    static let shared = GestorNotificaciones()
    
    private init() {}
    
    // 1. Pedir permiso al usuario
    func solicitarPermisos() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { concedido, error in
            if let error = error {
                print("Error al solicitar permisos de notificación: \(error.localizedDescription)")
            }
        }
    }
    
    // 2. Programar notificaciones para un partido concreto
    func programarNotificaciones(para partido: Partido, minutosAntes: [Int]) {
        // Primero cancelamos las que ya tuviera este partido por si ha cambiado la hora
        cancelarNotificaciones(para: partido)
        
        // Si el partido ya se ha jugado, no programamos nada
        guard !partido.finalizado else { return }
        
        let center = UNUserNotificationCenter.current()
        
        for minutos in minutosAntes {
            // Calculamos la fecha de la alarma restando los minutos a la fecha del partido
            let fechaAlarma = partido.fecha.addingTimeInterval(-Double(minutos) * 60)
            
            // Solo programamos si la alarma es en el futuro
            let estadio = partido.equipoLocal?.estadio?.nombre ?? "campo desconocido"
            let hora = partido.fecha.formatted(date: .omitted, time: .shortened)
            
            if fechaAlarma > Date() {
                let content = UNMutableNotificationContent()
                content.title = "\(partido.equipoLocal?.nombre ?? "Local") vs \(partido.equipoVisitante?.nombre ?? "Visitante") [\(hora)]"
   
                content.body = "\(estadio) | Empieza en \(textoPara(minutos: minutos))"
                content.sound = .default
                
                // Creamos el trigger basado en la fecha calculada
                let componentes = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: fechaAlarma)
                let trigger = UNCalendarNotificationTrigger(dateMatching: componentes, repeats: false)
                
                // Identificador único (ID del partido + los minutos) para poder borrarla luego
                let identificador = "\(partido.id.uuidString)-\(minutos)"
                let peticion = UNNotificationRequest(identifier: identificador, content: content, trigger: trigger)
                
                center.add(peticion) { error in
                    if let error = error {
                        print("Error al programar notificación: \(error.localizedDescription)")
                    }
                }
            }
        }
    }
    
    // 3. Cancelar las notificaciones de un partido (Ej: si se borra o se cambia la hora)
    func cancelarNotificaciones(para partido: Partido) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { peticiones in
            // Buscamos todas las notificaciones cuyo ID empiece por el ID del partido
            let identificadoresABorrar = peticiones
                .filter { $0.identifier.starts(with: partido.id.uuidString) }
                .map { $0.identifier }
            
            center.removePendingNotificationRequests(withIdentifiers: identificadoresABorrar)
        }
    }
    
    // 4. Actualizar todos los partidos de golpe (cuando cambias la configuración)
    func actualizarTodas(partidos: [Partido], minutos: [Int]) {
        for partido in partidos {
            programarNotificaciones(para: partido, minutosAntes: minutos)
        }
    }
    
    // Helper visual
    private func textoPara(minutos: Int) -> String {
        switch minutos {
        case 10: return "10 minutos"
        case 30: return "media hora"
        case 60: return "1 hora"
        case 120: return "2 horas"
        case 1440: return "1 día"
        case 2880: return "2 días"
        case 10080: return "1 semana"
        default: return "\(minutos) minutos"
        }
    }
}
