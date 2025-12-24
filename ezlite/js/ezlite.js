function setCookie(name,value,days) {
  var expires = '';
  if (days) {
    var date = new Date();
    date.setTime(date.getTime() + (days*24*60*60*1000));
    expires = '; Expires=' + date.toUTCString();
  }
  document.cookie = name + '=' + (value || '') + expires + '; Path=/; Secure=1; SameSite=Lax;';
}

function getCookie(name) {
  var nameEQ = name + '=';
  var ca = document.cookie.split(';');
  for(var i=0;i < ca.length;i++) {
    var c = ca[i];
    while (c.charAt(0)==' ') c = c.substring(1,c.length);
    if (c.indexOf(nameEQ) == 0) return c.substring(nameEQ.length,c.length);
  }
  return null;
}

function eraseCookie(name) {   
  document.cookie = name + '=; Path=/; Secure=1; SameSite=Lax; Expires=Thu, 01 Jan 1970 00:00:01 GMT;';
}

function checkUserTokenCookie() {
  var cookieToken = getCookie('userToken');
  var webpageToken = document.getElementById('userToken').value;  
  /* alert(cookieToken); */
  if (cookieToken != webpageToken) {
    // set token to cookie, if not set
    setCookie('userToken', webpageToken, 7);
    /* alert('set cookie'); */
  }
}

