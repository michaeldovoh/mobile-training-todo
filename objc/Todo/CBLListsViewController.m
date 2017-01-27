//
//  CBLListsViewController.m
//  Todo
//
//  Created by Pasin Suriyentrakorn on 1/26/17.
//  Copyright © 2017 Pasin Suriyentrakorn. All rights reserved.
//

#import "CBLListsViewController.h"
#import <CouchbaseLite/CouchbaseLite.h>
#import "AppDelegate.h"
#import "CBLUi.h"
#import "CBLTasksViewController.h"

@interface CBLListsViewController () <UISearchResultsUpdating> {
    UISearchController *_searchController;
    
    CBLDatabase *_database;
    NSString *_username;
    CBLQuery *_listQuery;
    CBLQuery *_searchQuery;
    NSArray* _listRows;
}

@end

@implementation CBLListsViewController

#pragma mark - UIViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    // Setup Search Controller:
    _searchController = [[UISearchController alloc] initWithSearchResultsController:nil];
    _searchController.searchResultsUpdater = self;
    self.tableView.tableHeaderView = _searchController.searchBar;
    
    AppDelegate *app = (AppDelegate *)[UIApplication sharedApplication].delegate;
    _database = app.database;
    _username = app.username;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self reload];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Database

- (void)reload {
    NSError *error;
    if (!_listQuery) {
        // Create an index: including task for search feature
        [_database createIndexOn:@[@"type", @"name"] error:nil];
        
        // Create a query
        _listQuery = [_database createQueryWhere:@"type == 'task-list'" orderBy:@[@"name"]
                                       returning:nil error:&error];
        if (!_listQuery) {
            NSLog(@"Error creating a query: %@", error);
            return;
        }
    }
    
    NSEnumerator *rows = [_listQuery run: &error];
    if (!rows)
        NSLog(@"Error querying task list: %@", error);
    
    _listRows = [rows allObjects];
    [self.tableView reloadData];
}

- (void)createTaskList:(NSString*)name {
    NSString *docId = [NSString stringWithFormat:@"%@.%@", _username, [NSUUID UUID].UUIDString];
    CBLDocument *doc = [_database documentWithID:docId];
    doc[@"type"] = @"task-list";
    doc[@"name"] = name;
    doc[@"owner"] = _username;
    
    NSError *error;
    if (![doc save: &error])
        [CBLUi showErrorDialog:self withMessage:@"Couldn't save task list" withError:error];
    [self reload];
}

- (void)updateTaskList:(CBLDocument *)doc withName:(NSString *)name {
    doc[@"name"] = name;
    NSError *error;
    if (![doc save: &error])
        [CBLUi showErrorDialog:self withMessage:@"Couldn't update task list" withError:error];
    [self reload];
}

- (void)deleteTaskList:(CBLDocument *)list {
    NSError *error;
    if (![list deleteDocument: &error])
        [CBLUi showErrorDialog:self withMessage:@"Couldn't delete task list" withError:error];
    [self reload];
}

- (void)searchList: (NSString*)name {
    NSError *error;
    if (!_searchQuery) {
        NSString *where = [NSString stringWithFormat:@"type == 'task-list' AND name contains[c] $NAME"];
        _searchQuery = [_database createQueryWhere:where orderBy:@[@"name"] returning:nil error:&error];
        if (!_searchQuery) {
            NSLog(@"Error creating a query: %@", error);
            return;
        }
    }
    
    _searchQuery.parameters = @{@"NAME": name};
    NSEnumerator *rows = [_searchQuery run: &error];
    if (!rows)
        NSLog(@"Error searching task list: %@", error);
    
    _listRows = [rows allObjects];
    [self.tableView reloadData];
}

#pragma mark - Actions

- (IBAction)addAction:(id)sender {
    [CBLUi showTextInputDialog:self withTitle:@"New Task List" withMessage:nil
           withTextFeildConfig:^(UITextField * _Nonnull textField) {
               textField.placeholder = @"List name";
               textField.autocapitalizationType = UITextAutocapitalizationTypeWords;
           } onOk:^(NSString * _Nonnull name) {
               [self createTaskList:name];
           }];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [_listRows count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"TaskListCell"
                                                            forIndexPath:indexPath];
    CBLQueryRow *row = _listRows[indexPath.row];
    cell.textLabel.text = row.document[@"name"];
    cell.detailTextLabel.text = nil;
    return cell;
}

-(NSArray<UITableViewRowAction *> *)tableView:(UITableView *)tableView
                 editActionsForRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Delete action:
    UITableViewRowAction *delete =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Delete"
                                         handler:
     ^(UITableViewRowAction *action, NSIndexPath *indexPath) {
         // Dismiss row actions:
         [tableView setEditing:NO animated:YES];
         
         // Delete list document:
         CBLDocument *doc = ((CBLQueryRow*)_listRows[indexPath.row]).document;
         [self deleteTaskList:doc];
    }];
    delete.backgroundColor = [UIColor colorWithRed:1.0 green:0.23 blue:0.19 alpha:1.0];
    
    // Update action:
    UITableViewRowAction *update =
        [UITableViewRowAction rowActionWithStyle:UITableViewRowActionStyleNormal
                                           title:@"Edit"
                                         handler:
     ^(UITableViewRowAction *action, NSIndexPath *indexPath) {
         // Dismiss row actions:
         [tableView setEditing:NO animated:YES];
         
         // Get the document:
         CBLDocument *doc = ((CBLQueryRow *)_listRows[indexPath.row]).document;
         
         // Display update list dialog:
         [CBLUi showTextInputDialog:self withTitle:@"Edit List" withMessage:nil
                withTextFeildConfig:^(UITextField *textField) {
                    textField.placeholder = @"List name";
                    textField.text = doc[@"name"];
                } onOk:^(NSString *name) {
                    // Update task list with a new name:
                    [self updateTaskList:doc withName:name];
                }];
    }];
    update.backgroundColor = [UIColor colorWithRed:0.0 green:0.48 blue:1.0 alpha:1.0];
    
    return @[delete, update];
}

#pragma mark - UISearchController

- (void)updateSearchResultsForSearchController:(UISearchController *)searchController {
    NSString *text = searchController.searchBar.text ?: @"";
    if ([text length] > 0)
        [self searchList:text];
    else
        [self reload];
}

#pragma mark - Navigation

- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    CBLQueryRow *row = (CBLQueryRow *)_listRows[[self.tableView indexPathForSelectedRow].row];
    CBLTasksViewController *controller = (CBLTasksViewController*)segue.destinationViewController;
    controller.taskList = row.document;
}

@end
