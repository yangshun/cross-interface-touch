$(function () {

  var canvas = new fabric.Canvas('drawing_board', {
    backgroundColor: 'rgb(255,255,224)',
    height: window.innerWidth * 0.75,
    width: window.innerWidth
  });
  var socket = io();
  var users = [];
  // Socket events
  socket.emit('screen');

  // Whenever the server emits 'user joined', log it in the chat body
  socket.on('user joined', function (userId) {
    console.log('New user joined: ', userId.newUserId);
    users.push(userId);
  });

  socket.on('user input touchmove', function (data) {
    var point = new fabric.Circle({
      radius: 20,
      fill: 'green',
      left: data.x,
      top: data.y
    });
    canvas.add(point);
  });

});
