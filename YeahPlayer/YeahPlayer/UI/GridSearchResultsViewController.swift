//
//  yeahPlayer sample code
//
//  Created by Alex Bird 07/03/2025.
//

import UIKit
import os

@MainActor
protocol GridSearchResultsDelegate: AnyObject {
    func itemSelected(pid: String, pidType: String)
}

class GridSearchResultsViewController: UIViewController {
    var items: [SearchItem] = [] {
        didSet {
            collectionView.reloadData()
        }
    }
    private let imageLoader = ImageLoader()
    
    weak var delegate: GridSearchResultsDelegate?
    
    lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = 40
        layout.minimumLineSpacing = 40
        
        // item size to fit 4 items across with spacing
        let padding: CGFloat = 60  // side padding
        let totalSpacing: CGFloat = layout.minimumInteritemSpacing * 3  // space between 4 items
        let availableWidth = UIScreen.main.bounds.width - padding - totalSpacing
        let itemWidth = availableWidth / 4
        let itemHeight = itemWidth * 0.7  // aspect ratio
        
        layout.itemSize = CGSize(width: itemWidth, height: itemHeight)
        layout.sectionInset = UIEdgeInsets(top: 40, left: 30, bottom: 40, right: 30)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .clear
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(SearchItemCell.self, forCellWithReuseIdentifier: "SearchItemCell")
        return collectionView
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
    }
    
    private func setupUI() {
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
}

extension GridSearchResultsViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return items.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "SearchItemCell", for: indexPath) as! SearchItemCell
        
        let item = items[indexPath.item]
        cell.configure(with: item)
        
        if let imageURL = item.imageURL {
            Task { [weak cell] in
                let image = await imageLoader.loadImage(from: imageURL)
                if let cell,
                   cell.pid == item.id {
                    cell.setImage(image)
                }
            }
        }
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let selectedItem = items[indexPath.item]
        delegate?.itemSelected(pid: selectedItem.id, pidType: selectedItem.type)
    }
}

extension GridSearchResultsViewController: UISearchResultsUpdating {
    func updateSearchResults(for searchController: UISearchController) {
        collectionView.reloadData()
    }
}

// MARK: - cells

class SearchItemCell: UICollectionViewCell {
    var pid: String?
    
    private let imageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        return imageView
    }()
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .headline)
        label.adjustsFontForContentSizeCategory = true
        return label
    }()
    
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true
        label.backgroundColor = UIColor(white: 0, alpha: 0.2)
        return label
    }()
    
    override init(frame: CGRect) {
        self.pid = nil
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(titleLabel)
        contentView.addSubview(subtitleLabel)
        
        imageView.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.heightAnchor.constraint(equalTo: contentView.heightAnchor, multiplier: 0.8),
            
            titleLabel.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            
            subtitleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            subtitleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            subtitleLabel.bottomAnchor.constraint(equalTo: imageView.bottomAnchor, constant: -10)
        ])
    }
    
    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        coordinator.addCoordinatedAnimations {
            self.transform = self.isFocused ? CGAffineTransform(scaleX: 1.1, y: 1.1) : .identity
        }
    }
    
    func configure(with item: SearchItem) {
        pid = item.id
        titleLabel.text = item.title
        subtitleLabel.text = item.subtitle
    }
    
    func setImage(_ image: UIImage?) {
        imageView.image = image
    }
}
