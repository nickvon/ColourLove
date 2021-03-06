//
//  ViewController.m
//  colors
//
// Copyright 2013 Alexis Creuzot
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

#import "ColorsVC.h"
#import "ColorDetailVC.h"

#import "Color.h"
#import "ColorCell.h"
#import "Constants.h"

@interface ColorsVC ()
@property (weak, nonatomic) IBOutlet UITableView * colorsTableView;
@property (weak, nonatomic) IBOutlet UISearchBar * searchBar;
@end

@implementation ColorsVC{
    NSMutableArray * colors;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    [self setEdgesForExtendedLayout:UIRectEdgeLeft | UIRectEdgeBottom | UIRectEdgeRight];
    self.title = @"Colors";
    [_searchBar setText:@""];
}

- (void)viewWillAppear:(BOOL)animated
{
    // Check if colors is nil, we need to refresh data if it's the case
    // We then check the database, and only proceed to do a web request
    // if the database doesn't return any results
    if(!colors){
        if([Color count] == 0){
            [self requestColors];
        }else{
            colors = [Color allRecords].mutableCopy;
            [_colorsTableView reloadData];
            NSLog(@"%@", [colors JSONRepresentation]);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    [_colorsTableView deselectRowAtIndexPath:_colorsTableView.indexPathForSelectedRow animated:YES];
}


#pragma mark - Local data

// In case of no internet connection
// parse json from a local file
- (void) parseColorsJSON
{
    NSString *jsonPath = [[NSBundle mainBundle] pathForResource:@"colors" ofType:@"json"];
    NSString *content = [NSString stringWithContentsOfFile:jsonPath encoding:NSUTF8StringEncoding error:nil];
    
    for(NSDictionary * colorDict in [content JSONValue]){
        Color * col = [[Color alloc] initWithDict:colorDict];
        [colors addObject:col];
    }
    [_colorsTableView reloadData];
    [SVProgressHUD showSuccessWithStatus:@"Done"];
}

#pragma mark - Networking

- (void) requestColors
{
    // Init client
    AFHTTPClient * client = [AFHTTPClient clientWithBaseURL:[NSURL URLWithString:URL_BASE]];
    // Launch progressHUD and request
    [SVProgressHUD showWithMaskType:SVProgressHUDMaskTypeGradient];
    [client getPath:@"colors"
         parameters:@{@"format":@"json", @"keywords":_searchBar.text}
            success:^(AFHTTPRequestOperation *operation, id responseObject) {
                
                // Refresh the data with the new values
                [Color dropAllRecords];
                colors = [NSMutableArray array];
                
                // Transaction to limit write hits on SQLite DB
                [ActiveRecord transaction:^{
                    for(NSDictionary * colorDict in [operation.responseString JSONValue]){
                        Color * col = [[Color newRecord]initWithDict:colorDict];
                        [col save];
                        [colors addObject:col];
                    }
                }];
                
                [_colorsTableView reloadData];
                [SVProgressHUD showSuccessWithStatus:@"Done"];
                
            }
            failure:^(AFHTTPRequestOperation *operation, NSError *error) {
                [SVProgressHUD showErrorWithStatus:error.localizedDescription];
            }];
}

#pragma mark - TableView datasource

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [colors count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString * CellIdentifier = @"ColorCell";
    ColorCell * cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if(cell == nil){
        cell = [[ColorCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
    }
    
    [cell displayForColor:colors[indexPath.row]];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    ColorDetailVC * detailController = [ColorDetailVC new];
    detailController.color = colors[indexPath.row];
    [self.navigationController pushViewController:detailController animated:YES];
}

#pragma mark - SearchBar methods

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar{
    [self requestColors];
    [_searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar
{
    [_searchBar resignFirstResponder];
}

@end
