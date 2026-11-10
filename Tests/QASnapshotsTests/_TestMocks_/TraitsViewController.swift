import UIKit

final class TraitsViewController: UIViewController {
    var traitsView: TraitsView? {
        viewIfLoaded as? TraitsView
    }

    override func loadView() {
        view = TraitsView()
    }
}
