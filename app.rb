require 'pry'
require 'sinatra'
require 'sinatra/reloader'
require 'pg'



def with_db
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  yield c
  c.close
end

get '/' do
  erb :index
end

# The Categories machinery:

get '/categories' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')

  @categories = c.exec_params("SELECT * FROM categories")
  erb :categories
end

get '/categories/new' do
  erb :new_category
end

post '/categories' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec_params("INSERT INTO categories (description) VALUES ($1)",
                  [params["description"]])

  new_category_id = c.exec_params("SELECT currval('categories_id_seq');").first["currval"]
  c.close
  redirect "/categories/#{new_category_id}"
end

get '/categories/:id' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  @category = c.exec_params("SELECT * FROM categories WHERE categories.id = $1;", [params[:id]]).first
  
  list_products = c.exec_params("
    SELECT p.name FROM categories AS c  
    INNER JOIN prodcat AS pc 
    ON pc.category_id = c.id
    INNER JOIN products AS p 
    ON pc.product_id = p.id
    WHERE c.id=$1;", [params[:id]] )

  @products_array = list_products.to_a

  c.close
  erb :category
end



# The Products machinery:

# Get the index of products
get '/products' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')

  # Get all rows from the products table.
  @products = c.exec_params("SELECT * FROM products;")
  c.close
  erb :products
end

# Get the form for creating a new product
get '/products/new' do
  erb :new_product
end

# POST to create a new product
post '/products' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')

  # Insert the new row into the products table.
  c.exec_params("INSERT INTO products (name, price, description) VALUES ($1,$2,$3)",
                  [params["name"], params["price"], params["description"]])

  # Assuming you created your products table with "id SERIAL PRIMARY KEY",
  # This will get the id of the product you just created.
  new_product_id = c.exec_params("SELECT currval('products_id_seq');").first["currval"]
  c.close
  redirect "/products/#{new_product_id}"
end

# Update a product
post '/products/:id' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')

  # Update the product.
  c.exec_params("UPDATE products SET (name, price, description) = ($2, $3, $4) WHERE products.id = $1 ",
                [params["id"], params["name"], params["price"], params["description"]])
  c.close
  redirect "/products/#{params["id"]}"
end

get '/products/:id/edit' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  @product = c.exec_params("SELECT * FROM products WHERE products.id = $1", [params["id"]]).first
  
  list_categories = c.exec_params("
    SELECT c.description FROM products as p 
    INNER JOIN prodcat AS pc 
    ON pc.product_id = p.id
    INNER JOIN categories AS c 
    ON pc.category_id = c.id
    WHERE p.id=$1;", [params[:id]] )
  
  @categories_array = list_categories.to_a

  all_categories = c.exec_params("
    SELECT * FROM products as p 
    INNER JOIN prodcat AS pc 
    ON pc.product_id = p.id
    INNER JOIN categories AS c 
    ON pc.category_id = c.id
    WHERE p.id=$1;", [params[:id]] )

  @every_category = all_categories.to_a
binding.pry
  c.close
  erb :edit_product


end
# DELETE to delete a product
post '/products/:id/destroy' do

  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec_params("DELETE FROM products WHERE products.id = $1", [params["id"]])
  c.close
  redirect '/products'
end

# GET the show page for a particular product
get '/products/:id' do
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  @product = c.exec_params("SELECT * FROM products WHERE products.id = $1;", [params[:id]]).first

  list_categories = c.exec_params("
    SELECT c.description FROM products as p 
    INNER JOIN prodcat AS pc 
    ON pc.product_id = p.id
    INNER JOIN categories AS c 
    ON pc.category_id = c.id
    WHERE p.id=$1;", [params[:id]] )
  
  @categories_array = list_categories.to_a

  c.close
  erb :product
end


# PRODUCTS: CREATE, SEED, DELETE TABLE

def create_products_table
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec %q{
  CREATE TABLE products (
    id SERIAL PRIMARY KEY,
    name varchar(255),
    price decimal,
    description text
  );
  }
  c.close
end

def drop_products_table
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec "DROP TABLE products;"
  c.close
end

def seed_products_table
  products = [["Laser", "325", "Good for lasering."],
              ["Shoe", "23.4", "Just the left one."],
              ["Wicker Monkey", "78.99", "It has a little wicker monkey baby."],
              ["Whiteboard", "125", "Can be written on."],
              ["Chalkboard", "100", "Can be written on.  Smells like education."],
              ["Podium", "70", "All the pieces swivel separately."],
              ["Bike", "150", "Good for biking from place to place."],
              ["Kettle", "39.99", "Good for boiling."],
              ["Toaster", "20.00", "Toasts your enemies!"],
             ]

  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  products.each do |p|
    c.exec_params("INSERT INTO products (name, price, description) VALUES ($1, $2, $3);", p)
  end
  c.close
end


# CATEGORIES: CREATE TABLE, SEED TABLE, DROP TABLE

def create_categories_table
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec %q{
  CREATE TABLE categories (
    id SERIAL PRIMARY KEY,
    description varchar(255)
  );
  }
  c.close
end

def drop_categories_table
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec "DROP TABLE categories;"
  c.close
end

def seed_categories_table
  categories = [["Education"],
              ["Appliances"],
              ["Toys"],
              ["Apparel"],
              ["Tools"],
              ["Hodge Podge"],
              ["Moving Parts"],
              ["Dangerous"],
             ]

  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  categories.each do |cat|
    c.exec_params("INSERT INTO categories (description) VALUES ($1);", cat)
  end
  c.close
end

# CREATE JOIN TABLE: PROD-CATEG
def create_productcategory_table
  c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  c.exec %q{
  CREATE TABLE prodcat (
    id SERIAL PRIMARY KEY,
    category_id INTEGER,
    product_id INTEGER
  );
  }
  c.close
end


def seed_prodcat_table

prodcat = [[8,1],
          [1,1]

             ]

c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
  prodcat.each do |pc|
    c.exec_params("INSERT INTO prodcat (category_id, product_id) VALUES ($1, $2);", pc)
  end
  c.close

end

# def join_categoryid_to_prodcat
#   c = PGconn.new(:host => "localhost", :dbname => 'sinatrastore')
#   c.exec ("
#     SELECT * FROM categories as cat
#     INNER JOIN prodcat AS pc 
#       ON pc.category_id=cat.id
#   ");
# end










