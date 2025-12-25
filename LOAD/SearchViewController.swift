import UIKit

final class SearchViewController: UITableViewController {
    private let suggestions = [
        "Recent Searches",
        "Trending",
        "Artists",
        "Albums",
        "Genres",
        "Playlists"
    ]

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Search"
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "SearchCell")
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        suggestions.count
    }

    override func tableView(
        _ tableView: UITableView,
        cellForRowAt indexPath: IndexPath
    ) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SearchCell", for: indexPath)
        var content = cell.defaultContentConfiguration()
        content.text = suggestions[indexPath.row]
        content.secondaryText = "Explore"
        cell.contentConfiguration = content
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}
