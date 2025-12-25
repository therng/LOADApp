import UIKit

final class HistoryViewController: UITableViewController {
    private let items = (1...30).map { "History Item \($0)" }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "History"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "HistoryCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        items.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "HistoryCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = items[indexPath.row]
        content.secondaryText = "Recently played"
        cell.contentConfiguration = content
        cell.selectionStyle = .none
        return cell
    }
}
