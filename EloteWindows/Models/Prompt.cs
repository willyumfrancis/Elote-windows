using System;

namespace EloteWindows.Models
{
    public class Prompt
    {
        public Guid Id { get; set; }
        public string Name { get; set; }
        public string Text { get; set; }

        public Prompt()
        {
            Id = Guid.NewGuid();
        }

        public Prompt(string name, string text) : this()
        {
            Name = name;
            Text = text;
        }

        public override bool Equals(object obj)
        {
            if (obj is Prompt other)
            {
                return Id == other.Id;
            }
            return false;
        }

        public override int GetHashCode()
        {
            return Id.GetHashCode();
        }
    }
}
