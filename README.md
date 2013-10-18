nitesi-admin
============
Perl documentation in /lib/TableEdit.pm

<div class="pod">
<div class="toc">
<div class="indexgroup">
<ul class="indexList indexList1">
  <li class="indexItem indexItem1"><a href="#NAME">NAME</a>
  </li><li class="indexItem indexItem1"><a href="#SYNOPSIS">SYNOPSIS</a>
  </li><li class="indexItem indexItem1"><a href="#CONFIGURATION">CONFIGURATION</a>
  <ul class="indexList indexList2">
    <li class="indexItem indexItem2"><a href="#DBIx_schema_loader">DBIx schema loader</a>
    </li><li class="indexItem indexItem2"><a href="#Database_config">Database config</a>
  </li></ul>
  </li><li class="indexItem indexItem1"><a href="#USE">USE</a>
  </li><li class="indexItem indexItem1"><a href="#FINE_TUNE">FINE TUNE</a>
  <ul class="indexList indexList2">
    <li class="indexItem indexItem2"><a href="#Column_label">Column label</a>
    </li><li class="indexItem indexItem2"><a href="#Object_/_Row_string_representation">Object / Row string representation</a>
    </li><li class="indexItem indexItem2"><a href="#Hidden_columns">Hidden columns</a>
    </li><li class="indexItem indexItem2"><a href="#Many_to_many">Many to many</a>
  </li></ul>
</li></ul>
</div>
</div>

<h1><a class="u" href="#___top" title="click to go to top of document" name="NAME">NAME <img alt="^" src="http://st.pimg.net/tucs/img/up.gif"></a></h1>

<p>Dancer - Table Edit</p>

<h1><a class="u" href="#___top" title="click to go to top of document" name="SYNOPSIS">SYNOPSIS <img alt="^" src="http://st.pimg.net/tucs/img/up.gif"></a></h1>

<p>Table Edit lets you edit database data.
It uses <a href="/perldoc?DBIx%3A%3AClass" class="podlinkpod">DBIx::Class</a> models for database metadata.</p>

<h1><a class="u" href="#___top" title="click to go to top of document" name="CONFIGURATION">CONFIGURATION <img alt="^" src="http://st.pimg.net/tucs/img/up.gif"></a></h1>

<p>You need a database and <a href="/perldoc?DBIx%3A%3AClass" class="podlinkpod">DBIx::Class</a> models for this module to work.
You can write your own <a href="/perldoc?DBIx%3A%3AClass" class="podlinkpod">DBIx::Class</a> models,
or use schema loader.</p>

<p>For now it only works with branched version of Tamplate::Flute available on <a href="https://github.com/gregapompe/Template-Flute" class="podlinkurl">https://github.com/gregapompe/Template-Flute</a>.</p>

<p>To make sure app uses this version of Flute,
set appropriate path in app.pm</p>

<pre class="sh_perl sh_sourceCode">        <span class="sh_comment">#!/usr/bin/env perl</span>
        <span class="sh_keyword">use</span> lib <span class="sh_string">'/home/Template-Flute/lib'</span><span class="sh_symbol">;</span>
        <span class="sh_keyword">use</span> Dancer<span class="sh_symbol">;</span>
        <span class="sh_keyword">use</span> TableEdit<span class="sh_symbol">;</span>
        dance<span class="sh_symbol">;</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document" name="DBIx_schema_loader">DBIx schema loader</a></h2>

<p><a href="/perldoc?DBIx%3A%3AClass%3A%3ASchema%3A%3ALoader" class="podlinkpod">DBIx::Class::Schema::Loader</a> perl script is included in /bin folder. All you have to do is set the database data and run it. This will create <a href="/perldoc?DBIx%3A%3AClass" class="podlinkpod">DBIx::Class</a> model files for you.</p>

<h2><a class="u" href="#___top" title="click to go to top of document" name="Database_config">Database config</a></h2>

<p>You also have to set Dancers DBCI connection in config.yml</p>

<pre class="sh_perl sh_sourceCode">        plugins<span class="sh_symbol">:</span> 
           DBIC<span class="sh_symbol">:</span>
            default<span class="sh_symbol">:</span>
              dsn<span class="sh_symbol">:</span> dbi<span class="sh_symbol">:</span>mysql<span class="sh_symbol">:</span>dbname<span class="sh_symbol">=</span>myDbName<span class="sh_symbol">;</span>host<span class="sh_symbol">=</span>localhost<span class="sh_symbol">;</span>port<span class="sh_symbol">=</span><span class="sh_number">3306</span>
              schema_class<span class="sh_symbol">:</span> TableEdit<span class="sh_symbol">::</span>Schema
              user<span class="sh_symbol">:</span> root
              pass<span class="sh_symbol">:</span> toor
              options<span class="sh_symbol">:</span>
                RaiseError<span class="sh_symbol">:</span> <span class="sh_number">1</span>
                PrintError<span class="sh_symbol">:</span> <span class="sh_number">1</span></pre>

<h1><a class="u" href="#___top" title="click to go to top of document" name="USE">USE <img alt="^" src="http://st.pimg.net/tucs/img/up.gif"></a></h1>

<p>Whit basic configuration done you can start using Table Edit. You will probably want to fine tune it a bit though.</p>

<h1><a class="u" href="#___top" title="click to go to top of document" name="FINE_TUNE">FINE TUNE <img alt="^" src="http://st.pimg.net/tucs/img/up.gif"></a></h1>

<p>Make sure you set all additional info below # DO NOT MODIFY THIS OR ANYTHING ABOVE! line in <a href="/perldoc?DBIx%3A%3AClass" class="podlinkpod">DBIx::Class</a> model.</p>

<p>For this example we will use folowing model.</p>

<pre class="sh_perl sh_sourceCode">        <span class="sh_keyword">use</span> utf8<span class="sh_symbol">;</span>
        <span class="sh_keyword">package</span> TableEdit<span class="sh_symbol">::</span>Schema<span class="sh_symbol">::</span>Result<span class="sh_symbol">::</span>User<span class="sh_symbol">;</span>
        
        <span class="sh_keyword">use</span> strict<span class="sh_symbol">;</span>
        <span class="sh_keyword">use</span> warnings<span class="sh_symbol">;</span>
        
        <span class="sh_keyword">use</span> base <span class="sh_string">'DBIx::Class::Core'</span><span class="sh_symbol">;</span>
        
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">table</span><span class="sh_symbol">(</span><span class="sh_string">"user"</span><span class="sh_symbol">);</span>
        
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">add_columns</span><span class="sh_symbol">(</span>
          <span class="sh_string">"id"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> data_type <span class="sh_symbol">=&gt;</span> <span class="sh_string">"integer"</span><span class="sh_symbol">,</span> is_auto_increment <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span><span class="sh_symbol">,</span> is_nullable <span class="sh_symbol">=&gt;</span> <span class="sh_number">0</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_string">"username"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> data_type <span class="sh_symbol">=&gt;</span> <span class="sh_string">"varchar"</span><span class="sh_symbol">,</span> is_nullable <span class="sh_symbol">=&gt;</span> <span class="sh_number">0</span><span class="sh_symbol">,</span> size <span class="sh_symbol">=&gt;</span> <span class="sh_number">45</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_string">"email"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> data_type <span class="sh_symbol">=&gt;</span> <span class="sh_string">"varchar"</span><span class="sh_symbol">,</span> is_nullable <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span><span class="sh_symbol">,</span> size <span class="sh_symbol">=&gt;</span> <span class="sh_number">90</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_string">"birthday"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> data_type <span class="sh_symbol">=&gt;</span> <span class="sh_string">"timestamp with time zone"</span><span class="sh_symbol">,</span> is_nullable <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_string">"internal_code"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> data_type <span class="sh_symbol">=&gt;</span> <span class="sh_string">"integer"</span><span class="sh_symbol">,</span> is_nullable <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_string">"created_date"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span>
            data_type     <span class="sh_symbol">=&gt;</span> <span class="sh_string">"timestamp with time zone"</span><span class="sh_symbol">,</span>
            default_value <span class="sh_symbol">=&gt;</span> <span class="sh_symbol">\</span><span class="sh_string">"current_timestamp"</span><span class="sh_symbol">,</span>
            is_nullable   <span class="sh_symbol">=&gt;</span> <span class="sh_number">0</span><span class="sh_symbol">,</span>
            original      <span class="sh_symbol">=&gt;</span> <span class="sh_cbracket">{</span> default_value <span class="sh_symbol">=&gt;</span> <span class="sh_symbol">\</span><span class="sh_string">"now()"</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
        <span class="sh_symbol">);</span>
        
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">set_primary_key</span><span class="sh_symbol">(</span><span class="sh_string">"id"</span><span class="sh_symbol">);</span>
        
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">belongs_to</span><span class="sh_symbol">(</span>
          <span class="sh_string">"company"</span><span class="sh_symbol">,</span>
          <span class="sh_string">"TableEdit::Schema::Result::Company"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> id <span class="sh_symbol">=&gt;</span> <span class="sh_string">"podjetje_id"</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> is_deferrable <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span><span class="sh_symbol">,</span> on_delete <span class="sh_symbol">=&gt;</span> <span class="sh_string">"CASCADE"</span><span class="sh_symbol">,</span> on_update <span class="sh_symbol">=&gt;</span> <span class="sh_string">"CASCADE"</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
        <span class="sh_symbol">);</span>
        
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">has_many</span><span class="sh_symbol">(</span>
          <span class="sh_string">"user_items"</span><span class="sh_symbol">,</span>
          <span class="sh_string">"eShopAdmin::Schema::Result::UserItem"</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> <span class="sh_string">"foreign.approval_id"</span> <span class="sh_symbol">=&gt;</span> <span class="sh_string">"self.approval_id"</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
          <span class="sh_cbracket">{</span> cascade_copy <span class="sh_symbol">=&gt;</span> <span class="sh_number">0</span><span class="sh_symbol">,</span> cascade_delete <span class="sh_symbol">=&gt;</span> <span class="sh_number">0</span> <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>
        <span class="sh_symbol">);</span>
                
        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">many_to_many</span><span class="sh_symbol">(</span><span class="sh_string">"items"</span><span class="sh_symbol">,</span> <span class="sh_string">"user_items"</span><span class="sh_symbol">,</span> <span class="sh_string">"id"</span><span class="sh_symbol">,</span> <span class="sh_cbracket">{</span>class<span class="sh_symbol">=&gt;</span><span class="sh_string">"Item"</span><span class="sh_symbol">,</span><span class="sh_cbracket">}</span><span class="sh_symbol">);</span>
        
        <span class="sh_comment"># Created by DBIx::Class::Schema::Loader v0.07033</span>
        <span class="sh_comment"># DO NOT MODIFY THIS OR ANYTHING ABOVE! md5sum:g5NE5itWUoKXqfEKXj/8Rg</span>
        
        
        <span class="sh_comment"># You can replace this text with custom code or comments, and it will be preserved on regeneration</span>
        <span class="sh_number">1</span><span class="sh_symbol">;</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document" name="Column_label">Column label</a></h2>

<p>You can override column label by specifying it</p>

<pre class="sh_perl sh_sourceCode">        __PACKAGE__<span class="sh_symbol">-&gt;</span>columns_info<span class="sh_symbol">-&gt;</span><span class="sh_cbracket">{</span>fname<span class="sh_cbracket">}</span><span class="sh_symbol">-&gt;</span><span class="sh_cbracket">{</span>label<span class="sh_cbracket">}</span> <span class="sh_symbol">=</span> <span class="sh_string">'Name'</span><span class="sh_symbol">;</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document" name="Object_/_Row_string_representation">Object / Row string representation</a></h2>

<p>Row often has to be represented as string (titles, drop-down selectors, ...) so it is a good idea to define a custum, human redable strigification method. For example users username, his id in parentheses and company if he / she has one. It could be just username or something much complicated.</p>

<pre class="sh_perl sh_sourceCode">        <span class="sh_keyword">use</span> overload fallback <span class="sh_symbol">=&gt;</span> <span class="sh_number">1</span><span class="sh_symbol">,</span>
        <span class="sh_string">'""'</span> <span class="sh_symbol">=&gt;</span> <span class="sh_symbol">\&amp;</span>to_string<span class="sh_symbol">;</span> 

        <span class="sh_keyword">sub</span> to_string <span class="sh_cbracket">{</span>
                <span class="sh_keyword">my</span> <span class="sh_variable">$self</span> <span class="sh_symbol">=</span> <span class="sh_keyword">shift</span><span class="sh_symbol">;</span>       
                <span class="sh_keyword">my</span> <span class="sh_variable">$company</span> <span class="sh_symbol">=</span> <span class="sh_variable">$self</span><span class="sh_symbol">-&gt;</span>company <span class="sh_symbol">||</span> <span class="sh_string">""</span><span class="sh_symbol">;</span>
                <span class="sh_keyword">return</span> <span class="sh_string">"$self-&gt;username ($self-&gt;id) $company"</span><span class="sh_symbol">;</span>
        <span class="sh_cbracket">}</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document" name="Hidden_columns">Hidden columns</a></h2>

<p>Some columns are used only internaly and you never want to see them in TableEdit. You can hide them.</p>

<pre class="sh_perl sh_sourceCode">        __PACKAGE__<span class="sh_symbol">-&gt;</span>columns_info<span class="sh_symbol">-&gt;</span><span class="sh_cbracket">{</span>internal_code<span class="sh_cbracket">}</span><span class="sh_symbol">-&gt;</span><span class="sh_cbracket">{</span>hidden<span class="sh_cbracket">}</span> <span class="sh_symbol">=</span> <span class="sh_number">1</span><span class="sh_symbol">;</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document" name="Many_to_many">Many to many</a></h2>

<p>"Has many" and "belongs_to" is automaticly detected. However, many to many DBIx::Class information doesn't provide enough information, so you have to specify it manualy. Only set resultset_attributes once, or it will be overwritten!</p>

<pre class="sh_perl sh_sourceCode">        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">resultset_attributes</span><span class="sh_symbol">(</span><span class="sh_cbracket">{</span> 
                many_to_many <span class="sh_symbol">=&gt;</span> <span class="sh_cbracket">{</span>
                        items <span class="sh_symbol">=&gt;</span> <span class="sh_cbracket">{</span>class <span class="sh_symbol">=&gt;</span> <span class="sh_string">'eShopAdmin::Schema::Result::Item'</span><span class="sh_symbol">,</span> where <span class="sh_symbol">=&gt;</span> <span class="sh_cbracket">{</span>inactive <span class="sh_symbol">=&gt;</span> <span class="sh_string">'false'</span><span class="sh_cbracket">}}</span><span class="sh_symbol">,</span>  
                <span class="sh_cbracket">}</span><span class="sh_symbol">,</span>              
        <span class="sh_cbracket">}</span><span class="sh_symbol">);</span></pre>

<h2><a class="u" href="#___top" title="click to go to top of document">Grid visible columns Often you don't care about all columns when you browse though rows or there are simply to many. You can specify a list of columns that will appear on grid. Only set resultset_attributes once, or it will be overwritten!</a></h2>

<pre class="sh_perl sh_sourceCode">        __PACKAGE__<span class="sh_symbol">-&gt;</span><span class="sh_function">resultset_attributes</span><span class="sh_symbol">(</span><span class="sh_cbracket">{</span>     
                grid_columns <span class="sh_symbol">=&gt;</span> <span class="sh_symbol">[</span><span class="sh_string">'approval_id'</span><span class="sh_symbol">,</span> <span class="sh_string">'item_id'</span><span class="sh_symbol">,</span> <span class="sh_string">'notify'</span><span class="sh_symbol">,</span> <span class="sh_string">'is_approved'</span><span class="sh_symbol">],</span>
        <span class="sh_cbracket">}</span><span class="sh_symbol">);</span></pre>

</div>