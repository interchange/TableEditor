package TableEdit::CRUD;

use Dancer ':syntax';
use Dancer::Plugin::Form;


get '/:class/list' => sub {	return forward '/list_grid.html'; };
get '/' => sub {	return forward '/index.html'; };


true;