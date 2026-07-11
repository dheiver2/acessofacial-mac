import Foundation

/// Ponto de entrada. Suporta um modo headless de teste:
///
///   AcessoFacial --test
///
/// usado para validar a lógica pura sem abrir a câmera/UI. Sem argumentos,
/// abre a interface gráfica normal.
@main
struct Main {
    static func main() {
        let args = CommandLine.arguments
        if let i = args.firstIndex(of: "--make-icon"), i + 1 < args.count {
            IconMaker.write(to: args[i + 1])
            exit(0)
        }
        if args.contains("--test") {
            exit(SelfTest.run())
        }
        AcessoFacialApp.main()
    }
}
