var all_variables = new Array();
var count = 0;

function zoom( amt, i ) {
  var invert = document.getElementById('invertScroll').checked ? -1: 1;
  all_variables[i]['zoomed'] += amt * 4 * invert;
}

function mousePressed( i ) {
  all_variables[i]['curCoords'][0] = all_variables[i]['ps'].mouseX;
  all_variables[i]['curCoords'][1] = all_variables[i]['ps'].mouseY;
  all_variables[i]['buttonDown'] = true;
}

function mouseReleased( i ) {
  all_variables[i]['buttonDown'] = false;
}

function render( i ) {
  var deltaX = all_variables[i]['ps'].mouseX - all_variables[i]['curCoords'][0];
  var deltaY = all_variables[i]['ps'].mouseY - all_variables[i]['curCoords'][1];
  
  if( all_variables[i]['buttonDown'] ) {
    all_variables[i]['rot'][0] += deltaX / all_variables[i]['ps'].width * 5;
    all_variables[i]['rot'][1] += deltaY / all_variables[i]['ps'].height * 5;
    
    all_variables[i]['curCoords'][0] = all_variables[i]['ps'].mouseX;
    all_variables[i]['curCoords'][1] = all_variables[i]['ps'].mouseY;
  }

  // transform point cloud
  all_variables[i]['ps'].translate(0, 0, all_variables[i]['zoomed']);
  
  all_variables[i]['ps'].rotateY(all_variables[i]['rot'][0]);
  all_variables[i]['ps'].rotateX(all_variables[i]['rot'][1]);
  
  // clear the canvas
 all_variables[i]['ps'].clear();
  
  // draw rendering
  var c = all_variables[i]['rendering'].getCenter();
  all_variables[i]['ps'].translate(-c[0], -c[1], -c[2]);
  all_variables[i]['ps'].render(all_variables[i]['rendering']);

  var fps = Math.floor(all_variables[i]['ps'].frameRate);
  if(fps < 1){
    fps = "< 1";
  }
  
}

function start( filename, canvas_id, intial_zoom ) {
   var i = count;
   count++;
   
  all_variables[i] = new Array();
  all_variables[i]['ps'] = new PointStream();

  all_variables[i]['buttonDown'] = false;
  all_variables[i]['zoomed'] = intial_zoom;
  all_variables[i]['rot'] = [0, 0];
  all_variables[i]['curCoords'] = [0, 0];
  
  all_variables[i]['ps'].setup(document.getElementById( canvas_id ));
  
  all_variables[i]['ps'].background([0, 0, 0, 0]);
  all_variables[i]['ps'].pointSize(5);

  all_variables[i]['ps'].onRender = function() { render( i); }
  all_variables[i]['ps'].onMouseScroll = function(amt) { zoom(amt, i); }
  all_variables[i]['ps'].onMousePressed = function() { mousePressed( i ); }
  all_variables[i]['ps'].onMouseReleased = function() { mouseReleased( i ); }
  
  all_variables[i]['rendering'] = all_variables[i]['ps'].load(filename);
}
