//
//  ECS189ViewController.m
//  DrawingApp
//
//  Created by Lion User on 2/11/12.
//  Copyright (c) 2012 __MyCompanyName__. All rights reserved.
//

#import "ECS189DrawingViewController.h"
#import "myShape.h"

@interface ECS189DrawingViewController() {
    bool tapped;
    bool undoPressed;
    NSInteger selectedIndex;
    NSInteger savedLineWidthValue;
    BOOL savedDashedState;
    CGPoint savedShapeStartpoint;
    CGPoint savedShapeEndpoint;
}

@property (weak, nonatomic) IBOutlet UIImageView *drawingPad;
@property (weak, nonatomic) IBOutlet UISlider *lineWidthSlider;
@property (weak, nonatomic) IBOutlet UISwitch *dashedLineSelector;
@property (weak, nonatomic) IBOutlet myUIPickerViewController *colorPicker;
@property (weak, nonatomic) IBOutlet UISegmentedControl *shapeSelector;
@property (weak, nonatomic) IBOutlet UITableView *saveFileTableView;

@property (strong, atomic) myShape *currentShape;
@property NSInteger currentColor;
@property (strong, nonatomic) NSMutableArray *collection;
@property (strong, nonatomic) NSMutableArray *pickerArray;
@property (strong, nonatomic) NSMutableArray *fileSaveArray;

- (IBAction)clearDrawingPad:(id)sender;
- (IBAction)colorPickerButton:(id)sender;
- (IBAction)undoButton:(id)sender;
- (IBAction)saveButton:(id)sender;
- (IBAction)lineWidthMoved:(id)sender;
- (IBAction)isDashMoved:(id)sender;
- (IBAction)deleteButtonPressed:(id)sender;

- (UIColor *)colorForRow:(NSInteger)row;
- (void)drawShapes;
- (void)drawShapesSubroutine:(myShape *)shapeToBeDrawn contextRef:(CGContextRef) context;
- (void)drawShapeSelector:(myShape *)shapeToBeDrawn selectorRect:(CGRect *) rect;
- (void)selectShapeOnScreen:(CGPoint) tapPoint;
- (void)clearSelectShapeOnScreen;
- (void)setCurrentShapeProperties;
- (void)setupFileSaveArray;
- (NSString *) pathForDataFile;
- (void) saveDataToDisk;
- (void) loadDataFromDisk;
@end

// Start implementation
@implementation ECS189DrawingViewController
@synthesize currentShape = _currentShape;   // Current shape the user is attempting to draw
@synthesize currentColor = _currentColor;   // The color selection

@synthesize drawingPad = _drawingPad;   // The drawing area
@synthesize shapeSelector = _shapeSelector; // The shape selection
@synthesize saveFileTableView = _saveFileTableView;
@synthesize lineWidthSlider = _lineWidthSlider; // Handle for the line width slider
@synthesize dashedLineSelector = _dashedLineSelector;   // Handle for the line dash picker

@synthesize colorPicker = _colorPicker; // Handle for the color picker, needs IMPROVEMENT
@synthesize pickerArray = _pickerArray; // Stores the colors
@synthesize collection = _collection;   // NSMutableArray that stores all the components for shape
@synthesize fileSaveArray = _fileSaveArray; // Lists the files saves

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Release any cached data, images, etc that aren't in use.
}


#pragma mark - View lifecycle
- (void)viewDidLoad
{
    [super viewDidLoad];
    _currentShape = [[myShape alloc] init];
    _currentColor = 0;    
    _fileSaveArray = [[NSMutableArray alloc] init];
    
    tapped = FALSE;
    undoPressed = FALSE;
    selectedIndex = -1;
    savedShapeStartpoint = CGPointMake(0, 0);
    savedShapeEndpoint = CGPointMake(0, 0);
    _saveFileTableView.hidden = YES;
    
    
    _pickerArray = [[NSMutableArray alloc] init];
    [_pickerArray addObject:@"Black"];
    [_pickerArray addObject:@"White"];
    [_pickerArray addObject:@"Red"];
    [_pickerArray addObject:@"Orange"];
    [_pickerArray addObject:@"Yellow"];
    [_pickerArray addObject:@"Green"];
    [_pickerArray addObject:@"Blue"];
    [_pickerArray addObject:@"Cyan"];
    [_pickerArray addObject:@"Violet"];
    
    [self setupFileSaveArray];    
    //[self loadDataFromDisk];
    
    if(_collection == nil) {
        _collection = [[NSMutableArray alloc] init];
    }
   
}

- (void)viewDidUnload
{

    [self setShapeSelector:nil];
    [self setDrawingPad:nil];
    [self setLineWidthSlider:nil];
    [self setDashedLineSelector:nil];
    [self setSaveFileTableView:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
    [self saveDataToDisk];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return YES;
}

#pragma mark - drawing functions

- (void)drawShapes {
    //NSLog(@"In drawShapes!");
    
    UIGraphicsBeginImageContext(_drawingPad.frame.size);
    CGContextRef context = UIGraphicsGetCurrentContext();

    for(myShape *i in _collection) {
        [self drawShapesSubroutine:i contextRef:context];
        if(i.selected == true) {
            CGContextSetLineWidth(context, 1.0f);
            CGContextSetStrokeColorWithColor(context, [[UIColor darkGrayColor] CGColor]);
            float num[] = {6.0, 6.0};
            CGContextSetLineDash(context, 0.0, num, 2);
            
            CGRect rectangle;
            [self drawShapeSelector:i selectorRect: &rectangle];
            CGContextAddRect(context, rectangle);        
            CGContextStrokePath(context);
            
            
            //tapped = true;
        }
    }
      
    if(!tapped && !undoPressed && (selectedIndex == -1))
        [self drawShapesSubroutine:_currentShape contextRef:context];

    _drawingPad.image = UIGraphicsGetImageFromCurrentImageContext();
	UIGraphicsEndImageContext();
}

- (void)drawShapesSubroutine:(myShape *)shapeToBeDrawn contextRef:(CGContextRef)context {
    CGContextSetLineWidth(context, shapeToBeDrawn.lineWidth);
    CGContextSetStrokeColorWithColor(context, [[self colorForRow:shapeToBeDrawn.color] CGColor]);
    
    // Setting the dashed parameter
    if(shapeToBeDrawn.isDashed == true){
        float num[] = {6.0f+shapeToBeDrawn.lineWidth/2.0f, 6.0f+shapeToBeDrawn.lineWidth/2.0f};
        CGContextSetLineDash(context, 0.0, num, 2); 
    }
    else {
        CGContextSetLineDash(context, 0.0, NULL, 0);
    }
    
    
    if(shapeToBeDrawn.shape == 0) { //line
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, shapeToBeDrawn.startPoint.x, shapeToBeDrawn.startPoint.y);
        CGContextAddLineToPoint(context, shapeToBeDrawn.endPoint.x, shapeToBeDrawn.endPoint.y);
        
        CGContextClosePath(context);        
        CGContextStrokePath(context);
    }
    else if(shapeToBeDrawn.shape == 1) {    //Rectangle
        
        CGRect rectangle = CGRectMake(shapeToBeDrawn.startPoint.x,
                                      shapeToBeDrawn.startPoint.y,
                                      shapeToBeDrawn.endPoint.x - shapeToBeDrawn.startPoint.x,
                                      shapeToBeDrawn.endPoint.y - shapeToBeDrawn.startPoint.y);
        
        CGContextAddRect(context, rectangle);        
        CGContextStrokePath(context);
    }
    else if(shapeToBeDrawn.shape == 2) {    //Circle
        float X = shapeToBeDrawn.endPoint.x - shapeToBeDrawn.startPoint.x;
        float Y = shapeToBeDrawn.endPoint.y - shapeToBeDrawn.startPoint.y;
        float radius = sqrtf(X*X + Y*Y);
        CGContextAddArc(context, shapeToBeDrawn.startPoint.x, shapeToBeDrawn.startPoint.y, radius, 0, M_PI * 2.0, 1);
        CGContextStrokePath(context);               
    }
}

-(void)drawShapeSelector:(myShape *)shapeToBeDrawn selectorRect:(CGRect *) rect {
    float x, y, width, height;
    
    if(shapeToBeDrawn.shape == 0 || shapeToBeDrawn.shape == 1) { //Line & rectangle
        if(shapeToBeDrawn.startPoint.x < shapeToBeDrawn.endPoint.x) {
            x = shapeToBeDrawn.startPoint.x - SELECTMARGIN;
            width = shapeToBeDrawn.endPoint.x - shapeToBeDrawn.startPoint.x + 2*SELECTMARGIN;
        }
        else {
            x = shapeToBeDrawn.endPoint.x - SELECTMARGIN;
            width = shapeToBeDrawn.startPoint.x - shapeToBeDrawn.endPoint.x + 2*SELECTMARGIN;
        }
        
        if(shapeToBeDrawn.startPoint.y < shapeToBeDrawn.endPoint.y) {
            y = shapeToBeDrawn.startPoint.y - SELECTMARGIN;
            height = shapeToBeDrawn.endPoint.y - shapeToBeDrawn.startPoint.y + 2*SELECTMARGIN;
        }
        else {
            y = shapeToBeDrawn.endPoint.y - SELECTMARGIN;
            height = shapeToBeDrawn.startPoint.y - shapeToBeDrawn.endPoint.y + 2*SELECTMARGIN;
        }
        
    }
    else if(shapeToBeDrawn.shape == 2) {    // Circle
        float r, dx, dy;
        dx = shapeToBeDrawn.endPoint.x - shapeToBeDrawn.startPoint.x;
        dy = shapeToBeDrawn.endPoint.y - shapeToBeDrawn.startPoint.y;    
        r = sqrtf(dx*dx + dy*dy);   // Radius of our shape
        
        x = shapeToBeDrawn.startPoint.x - r - SELECTMARGIN;
        y = shapeToBeDrawn.startPoint.y - r - SELECTMARGIN;
        
        width = height = 2*(r+SELECTMARGIN);        
    }
    else {
        //NSLog(@"drawShapeSelector, shouldn't be here!");
    }
    
    x -= shapeToBeDrawn.lineWidth/2.0f;
    y -= shapeToBeDrawn.lineWidth/2.0f;
    width += shapeToBeDrawn.lineWidth;
    height += shapeToBeDrawn.lineWidth;
    
    *rect = CGRectMake(x, y, width, height);
}


#pragma mark - File Saving
- (NSString *) pathForDataFile
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *folder = @"~/Library/Application Support/DrawingApp/";
    folder = [folder stringByExpandingTildeInPath];
    
    if ([fileManager fileExistsAtPath: folder] == NO)
    {
        [fileManager createDirectoryAtPath:folder withIntermediateDirectories:YES attributes:nil error:nil];
    }
    
    NSString *fileName = @"example.DrawingApp";
    return [folder stringByAppendingPathComponent: fileName];    
}

- (void) saveDataToDisk
{
    NSString * path = [self pathForDataFile];
    
    NSMutableData *data = [[NSMutableData alloc] init];
    NSKeyedArchiver *archiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
    [archiver encodeObject:_collection forKey:@"collection"];
    [archiver finishEncoding];
    
    if(![data writeToFile:path atomically:YES]) {
        NSLog(@"Didn't work!");
    }
}

- (void) loadDataFromDisk
{
    NSString * path = [self pathForDataFile];
    
    if([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSMutableData *data = [[NSMutableData alloc] initWithContentsOfFile:path];
        NSKeyedArchiver *unarchiver = [[NSKeyedArchiver alloc] initForWritingWithMutableData:data];
    
        _collection = [unarchiver decodeObjectForKey:@"collection"];
        //NSLog(@"collection: %d",_collection.count);
        [self drawShapes];
    }
}


- (void) applicationWillTerminate: (NSNotification *)note
{
    [self saveDataToDisk];
}

#pragma mark - touch interface

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
    //NSLog(@"In touchesBegan!");
    tapped = false;    
    UITouch *touch = [touches anyObject];
    CGPoint tempPoint = [touch locationInView:_drawingPad];
    _currentShape.startPoint = CGPointMake(tempPoint.x, tempPoint.y);
    
    NSInteger touchesBeganSelectedIndex = -1;   // Checking to see if the new point still selectes the right shape.
    
    for(myShape* i in [_collection reverseObjectEnumerator]) {
        if([i pointContainedInShape:tempPoint]) {
            touchesBeganSelectedIndex = [_collection indexOfObject:i];
            break;
        }
    }
    
    if((touchesBeganSelectedIndex == -1) || (touchesBeganSelectedIndex != selectedIndex)) {    // If the newly touched area isn't previously tapped shape, then don't move
        selectedIndex = -1;
        [self clearSelectShapeOnScreen];
    }
    else {  // Newly touched point is within the previously selected shape, store the original points.
        myShape *obj = [_collection objectAtIndex:selectedIndex];
        savedShapeStartpoint = obj.startPoint;
        savedShapeEndpoint = obj.endPoint;
    }
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event {
    //NSLog(@"In touchesMoved!");
    UITouch *touch = [touches anyObject];
    CGPoint tempPoint = [touch locationInView:_drawingPad];
    
    // Setting properties
    _currentShape.endPoint = CGPointMake(tempPoint.x, tempPoint.y);
    
    if(selectedIndex == -1){
        [self setCurrentShapeProperties];
    }
    else {
        float dx = _currentShape.endPoint.x - _currentShape.startPoint.x,
            dy = _currentShape.endPoint.y - _currentShape.startPoint.y;
        //NSLog(@"(%f,%f)", dx, dy);
        myShape *obj = [_collection objectAtIndex:selectedIndex];
        obj.startPoint = CGPointMake(savedShapeStartpoint.x + dx, savedShapeStartpoint.y + dy);
        obj.endPoint = CGPointMake(savedShapeEndpoint.x + dx, savedShapeEndpoint.y + dy);
    }        
    
    [self drawShapes];
    _colorPicker.hidden = YES;
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event {
    //NSLog(@"In touchesEnded!");
    UITouch *touch = [touches anyObject];
    CGPoint tempPoint = [touch locationInView:_drawingPad];
    //NSLog(@"%f,%f",tempPoint.x,tempPoint.y);
    //NSLog(@"%@s",[_colorPicker pointInside:tempPoint withEvent:event] ? @"Yes": @"No");
    
    // Check to see if it's a tap
    if(CGPointEqualToPoint(tempPoint, _currentShape.startPoint) == NO) {    // Drag
        //NSLog(@"You dragged!");
        
        // Setting properties
        _currentShape.endPoint = CGPointMake(tempPoint.x, tempPoint.y);
        
        if(selectedIndex == -1){
            [self setCurrentShapeProperties];
            [_collection addObject: [[myShape alloc] initCopy:_currentShape]];
        }
        else {
            float dx = _currentShape.endPoint.x - _currentShape.startPoint.x,
            dy = _currentShape.endPoint.y - _currentShape.startPoint.y;
            NSLog(@"(%f,%f)", dx, dy);
            myShape *obj = [_collection objectAtIndex:selectedIndex];
            obj.startPoint = CGPointMake(savedShapeStartpoint.x + dx, savedShapeStartpoint.y + dy);
            obj.endPoint = CGPointMake(savedShapeEndpoint.x + dx, savedShapeEndpoint.y + dy);
        } 
        [self drawShapes];
    }
    else {  // Tap
        tapped = true;
        [self selectShapeOnScreen:(CGPoint) tempPoint];
    }
}

- (void)setCurrentShapeProperties {
    _currentShape.shape = [_shapeSelector selectedSegmentIndex];
    _currentShape.lineWidth = _lineWidthSlider.value;
    _currentShape.isDashed = _dashedLineSelector.on;
    _currentShape.color = _currentColor;
}

#pragma mark - Working...

- (void)selectShapeOnScreen:(CGPoint) tapPoint {
    //NSLog(@"You tapped!");
    
    selectedIndex = -1;
    for(myShape* i in [_collection reverseObjectEnumerator]) {
        if([i pointContainedInShape:tapPoint]) {
            //NSLog(@"Selected!");
            i.selected = TRUE;
            _lineWidthSlider.value = i.lineWidth;
            _dashedLineSelector.on = i.isDashed;
            [_colorPicker selectRow:i.color inComponent:0 animated:YES];
            selectedIndex = [_collection indexOfObject:i];
            break;
        }
    }
  
    [self drawShapes];
}

- (void)clearSelectShapeOnScreen {
    for(myShape *i in _collection) {
        i.selected = FALSE;
    }
}

#pragma mark - Color picker

- (IBAction)colorPickerButton:(id)sender {
    //NSLog(@"Clicked colorPickerButton");
    
    _colorPicker.alpha = ALPHAOPAQUE;    
    if(_colorPicker.hidden == YES) {
        _colorPicker.hidden = NO;
    }
    else {
        _colorPicker.hidden = YES;
    }
}

-(UIColor *)colorForRow:(NSInteger)row {
    switch (row) {
        case 0:
            return [UIColor blackColor];
        case 1:
            return [UIColor whiteColor];
        case 2:
            return [UIColor redColor];
        case 3:
            return [UIColor orangeColor];
        case 4:
            return [UIColor yellowColor];
        case 5:
            return [UIColor greenColor];
        case 6:
            return [UIColor blueColor];
        case 7:
            return [UIColor cyanColor];
        case 8:
            return [UIColor purpleColor];
        default:
            return [UIColor blackColor];
            break;
    }
    
}


- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)thePickerView {    
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)thePickerView numberOfRowsInComponent:(NSInteger)component {    
    return [_pickerArray count];
}

- (NSString *)pickerView:(UIPickerView *)thePickerView titleForRow:(NSInteger)row forComponent:(NSInteger)component {
    return [_pickerArray objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)thePickerView didSelectRow:(NSInteger)row inComponent:(NSInteger)component {    
    //NSLog(@"Selected Color: %@. Index of selected color: %i", [_pickerArray objectAtIndex:row], row);
    _currentColor = row;
    if(selectedIndex >= 0) {
        myShape *obj = [_collection objectAtIndex:selectedIndex];
        obj.color = _currentColor;
        [self drawShapes];
    }
    
}

#pragma mark - Table View
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return _fileSaveArray.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *tableIdentifier = @"fileSaveTable";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:tableIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc]initWithStyle:UITableViewCellStyleDefault reuseIdentifier:tableIdentifier];        
    }
    
    NSUInteger row = [indexPath row];
    cell.textLabel.text = [_fileSaveArray objectAtIndex:row];
    return cell;

}

- (void)setupFileSaveArray {
    
}

#pragma mark - Buttons & Features

- (IBAction)undoButton:(id)sender {
    //NSLog(@"Clicked undoButton");
    //NSLog(@"count: %d", _collection.count);
    if(_collection.count > 0) {
        [_collection removeLastObject];
        undoPressed = TRUE;
        [self drawShapes];
    };
    undoPressed = FALSE;
    //NSLog(@"count: %d", _collection.count);
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if(buttonIndex == 1) {
        [_collection removeAllObjects];
        _drawingPad.image = nil;
    }
}

- (IBAction)clearDrawingPad:(id)sender {
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Clear All"
                                                    message:@"Are you sure you want to clear everything?"
                                                   delegate:self
                                          cancelButtonTitle:@"Cancel"
                                          otherButtonTitles:@"YES", nil];
    [alert show];
}

- (IBAction)saveButton:(id)sender {
    [self saveDataToDisk];
}
- (IBAction)lineWidthMoved:(id)sender {
    if(selectedIndex >= 0){
        myShape *obj = [_collection objectAtIndex:selectedIndex];
        obj.lineWidth = _lineWidthSlider.value;
        [self drawShapes];
    }
}

- (IBAction)isDashMoved:(id)sender {
    if(selectedIndex >= 0){
        myShape *obj = [_collection objectAtIndex:selectedIndex];
        obj.isDashed = _dashedLineSelector.on;
        [self drawShapes];
    }
}
- (IBAction)deleteButtonPressed:(id)sender {
    if(selectedIndex >= 0) {
        [_collection removeObjectAtIndex:selectedIndex];
        [self drawShapes];
        selectedIndex = -1;
    }
}
@end
