/**
 * This application displays documentation generated by the docgen tool
 * found at dart-repo/dart/pkg/docgen. 
 * 
 * The Yaml file outputted by the docgen tool will be read in to 
 * generate [Page] and [Category] and [CompositeContainer]. 
 * Pages, Categories and CategoryItems are used to format and layout the page.
 */
// TODO(janicejl): Add a link to the dart docgen landing page in future. 
library dartdoc_viewer;

import 'dart:async';
import 'dart:html';

import 'package:dartdoc_viewer/data.dart';
import 'package:dartdoc_viewer/item.dart';
import 'package:dartdoc_viewer/read_yaml.dart';
import 'package:dartdoc_viewer/search.dart';
import 'package:web_ui/web_ui.dart';

// TODO(janicejl): YAML path should not be hardcoded. 
// Path to the YAML file being read in. 
const sourcePath = '../../docs/library_list.txt';

/// The [Viewer] object being displayed.
Viewer viewer;

/// The Dartdoc Viewer application state.
class Viewer {
  
  Future finished;

  /// The homepage from which every [Item] can be reached.
  @observable Home homePage;
  
  /// The current page being shown.
  @observable Item currentPage;

  // Private constructor for singleton instantiation.
  Viewer._() {
    var manifest = retrieveFileContents(sourcePath);
    finished = manifest.then((response) {
      var libraries = response.split('\n');
      currentPage = new Home(libraries);
      homePage = currentPage;
    });
  }
  
  /// The title of the current page.
  String get title => currentPage == null ? '' : currentPage.decoratedName;
  
  /// Updates [currentPage] to be [page].
  void _updatePage(Item page) {
    if (page != null) {
      currentPage = page;
    }
  }
  
  /// Creates a list of [Item] objects describing the path to [currentPage].
  List<Item> get breadcrumbs => [homePage]..addAll(currentPage.path);
  
  /// Looks for the correct [Item] described by [location]. If it is found,
  /// [currentPage] is updated and state is not pushed to the history api.
  /// Returns a [Future] to determine if a link was found or not.
  /// [location] is a [String] path to the location (either a qualified name
  /// or a url path).
  Future _handleLinkWithoutState(String location) {
    if (location != null && location != '') {
      // An extra '/' at the end of the url must be removed.
      if (location.endsWith('/')) 
        location = location.substring(0, location.length - 1);
      // Converts to a qualified name from a url path.
      location = location.replaceAll('/', '.');
      var libraryName = location.split('.').first;
      // Since library names can contain '.' characters, the library part
      // of the input contains '-' characters replacing the '.' characters
      // in the original qualified name to make finding a library easier. These
      // must be changed back to '.' characters to be true qualified names.
      location = location.replaceAll('-', '.');
      if (location == 'home') {
        _updatePage(homePage);
        return new Future.value(true);
      }
      var destination = pageIndex[location];
      if (destination != null) {
        _updatePage(destination);
        return new Future.value(true);
      } else {
        var member = homePage.itemNamed(libraryName);
        if (member is Placeholder) {
          return homePage.loadLibrary(member).then((_) {
            destination = pageIndex[location];
            if (destination != null) _updatePage(destination);
            return destination != null;
          });
        } 
      }
    }
    return new Future.value(false);
  }
  
  /// Looks for the correct [Item] described by [location]. If it is found, 
  /// [currentPage] is updated and state is pushed to the history api.
  void handleLink(String location) {
    _handleLinkWithoutState(location).then((response) {
      if (response) _updateState(currentPage);
    });
  }
  
  /// Updates [currentPage] to [page] and pushes state for navigation.
  void changePage(Item page) {
    if (page is Placeholder) {
      homePage.loadLibrary(page).then((response) {
        _updatePage(response);
        _updateState(response);
      });
    } else {
      if (page is Class && !page.isLoaded) {
        page.loadClass();
        buildHierarchy(page, currentPage);
      }
      _updatePage(page);
      _updateState(page);
    }
  }
  
  /// Pushes state to history for navigation in the browser.
  void _updateState(Item page) {
    String url = '#home';
    for (var member in page.path) {
      url = url == '#home' ? '#${libraryNames[member.name]}' : 
        '$url/${member.name}';
    }
    window.history.pushState(url, url.replaceAll('/', '->'), url);
  }
}

/// The latest url reached by a popState event.
String location;

/// Listens for browser navigation and acts accordingly.
void startHistory() {
  window.onPopState.listen((event) {
    location = window.location.hash.replaceFirst('#', '');
    if (viewer.homePage != null) {
      if (location != '') viewer._handleLinkWithoutState(location);
      else viewer._handleLinkWithoutState('home');
    }
  });
}

/// Handles browser navigation.
main() {
  startHistory();
  viewer = new Viewer._();
  // If a user navigates to a page other than the homepage, the viewer
  // must first load fully before navigating to the specified page.
  viewer.finished.then((_) {
    if (location != null && location != '') {
      viewer._handleLinkWithoutState(location);
    }
    
    retrieveFileContents('../../docs/index.txt').then((String list) {
      index.addAll(list.split('\n'));
    });
  });
}