-- Create products table
CREATE TABLE IF NOT EXISTS products (
                                        id SERIAL PRIMARY KEY,
                                        name VARCHAR(255) NOT NULL,
    price DECIMAL(10, 2) NOT NULL,
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
    );

-- Create orders table
CREATE TABLE IF NOT EXISTS orders (
                                      id SERIAL PRIMARY KEY,
                                      product_id INTEGER NOT NULL,
                                      quantity INTEGER NOT NULL DEFAULT 1,
                                      total_price DECIMAL(10, 2) NOT NULL,
    status VARCHAR(50) DEFAULT 'pending',
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id)
    );

-- Insert sample products
INSERT INTO products (name, price, description) VALUES
                                                    ('Laptop', 999.99, 'High-performance laptop'),
                                                    ('Mouse', 29.99, 'Wireless mouse'),
                                                    ('Keyboard', 79.99, 'Mechanical keyboard'),
                                                    ('Monitor', 299.99, '27-inch LED monitor'),
                                                    ('Headphones', 149.99, 'Noise-cancelling headphones');