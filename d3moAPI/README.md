DB->User ID=postgres;Password=postgres;Server=localhost;Port=5433;Database=SimpleDb;Pooling=true
dotnet ef migrations add InitialCreate
dotnet ef database update

stop container: docker compose down 
rebuild and push: docker compose up --build